# frozen_string_literal: true

require("google/cloud/pubsub")

class Pubsub
  MORGUE_QUEUE = :morgue

  attr_reader :subscribers

  def initialize
    @topics = {}
    @subscriptions = {}
  end

  # @param topic [JSON] The serialized job
  # @param queue_name [String] The topic name
  # @param at [Time] The time when this job should be executed (optional)
  def publish(job_data, queue_name:)
    topic = find_or_create_topic(queue_name)
    subscription = find_or_create_subscription_for_topic(topic, name: queue_name)
    topic.publish_async(job_data)

    subscriber =
      if queue_name == MORGUE_QUEUE
        Dequeuer.new(subscription)
          .on_dequeue do |job_data|
            JobsStats.add_dead_job(job_data)
            JobsStats.display
          end
          .start
      else
        Dequeuer.new(subscription)
          .on_dequeue do |job_data|
            error = ActiveJob::Base.execute(job_data)
            JobsStats.add_success_job(job_data) unless error
            JobsStats.display
          end
          .after_retries do |data, _error|
            publish(data, queue_name: MORGUE_QUEUE)
          end
          .start
      end
  end

  # Creates and memoizes a client.
  #
  # @return [Google::Cloud::PubSub]
  def client
    @client ||= Google::Cloud::PubSub.new(project_id: "project-tiago")
  end

  private

  # @param name [String] The name of the topic to find or create
  def find_or_create_topic(name)
    @topics[name] ||= client.topic(name) || client.create_topic(name)
  end

  # @param topic [Pubsub::Topic] The subscription to find or create for a given topic
  # @param name [String] The name of the topic to find or create
  def find_or_create_subscription_for_topic(topic, name:)
    @subscriptions[name] ||= topic.subscription(name) || topic.subscribe(name)
  end

  class Dequeuer
    def initialize(subscription)
      @subscription = subscription
    end

    def start
      @subscriber = @subscription.listen do |received_message|
        received_message.acknowledge!
        job_data = JSON.parse(received_message.data)["job_data"]
        @on_dequeue_callback&.call(job_data)

        @subscriber.on_error do |exception|
          puts "#on_error callback reached!"
          puts "Exception: #{exception.class} #{exception.message}"
        end
      # Retried enough times and now error bubbles up and we send the job to the morgue
      rescue GenericJob::Error => error
        received_message.acknowledge!
        @after_retries&.call(received_message.data, error)
      end

      @subscriber.start
      @subscriber
    end

    def on_dequeue(&block)
      @on_dequeue_callback = block
      self
    end

    def after_retries(&block)
      @after_retries = block
      self
    end
  end
end

# frozen_string_literal: true

module ActiveJob
  module QueueAdapters
    class PubsubAdapter
      attr_reader :pubsub

      def initialize
        @pubsub = Pubsub.new
      end

      # Enqueue a job to be performed.
      #
      # @param [ActiveJob::Base] job The job to be performed.
      def enqueue(job)
        job_data = JobWrapper.new(job).to_json
        pubsub.publish(job_data, queue_name: job.queue_name)
      end

      # Enqueue a job to be performed at a certain time.
      #
      # @param [ActiveJob::Base] job The job to be performed.
      # @param [Float] timestamp The time to perform the job.
      def enqueue_at(job, timestamp)
        delay = timestamp - Time.current.to_f
        if delay > 0
          task = Concurrent::ScheduledTask.execute(delay) do
            wrapper = JobWrapper.new(job)
            job_data = wrapper.to_json
            pubsub.publish(job_data, queue_name: job.queue_name)
          end

          task.execute
        end
      end

      class JobWrapper
        def initialize(job)
          job.provider_job_id = SecureRandom.uuid
          @job_data = job.serialize
        end
      end
    end
  end
end

class GenericJob < ApplicationJob
  class Error < StandardError; end

  queue_as :default
  retry_on Error, wait: 20.seconds, attempts: 2, queue: :default

  def perform(error_chance)
    if rand(1..100) <= error_chance
      puts "Job: ##{self.job_id} failed! Retries: (#{self.executions})"
      raise Error, "Custom error message"
    end

    time_executing = rand(0..5)
    sleep(time_executing)
    digest = Digest::MD5.hexdigest(self.provider_job_id)
    puts "Job ##{self.job_id} executed with result: #{digest} in #{time_executing} secs"
  end
end
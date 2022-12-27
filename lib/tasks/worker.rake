# frozen_string_literal: true

namespace(:worker) do
  desc("Run the worker")

  # Usage: docker compose run --rm web bin/rake worker:run'[<interval>,<jobs_per_second>,<error_chance>]'
  # interval(Integer): total time enqueing jobs (in seconds)
  # jobs_per_second(Integer): jobs produced every second of interval
  # error_chance(Integer): in percentage, example: 50(half will fail) or 0(none will fail)
  task(:run, %i[interval jobs_per_second error_chance] => :environment) do |_task, args|
    DEFAULT_INTERVAL = 3
    DEFAULT_JOBS_PER_SECOND = 5
    DEFAULT_ERROR_CHANCE = 50

    puts "Worker starting..."
    interval = args[:interval].presence&.to_i || DEFAULT_INTERVAL # seconds
    jobs_per_second = args[:jobs_per_second].presence&.to_i || DEFAULT_JOBS_PER_SECOND
    error_chance = args[:error_chance].presence&.to_i || DEFAULT_ERROR_CHANCE

    JobsStats.set_total_jobs_count(interval * jobs_per_second)

    # Gracefully shut down the subscriber on program exit, blocking until
    # all received messages have been processed or 10 seconds have passed
    at_exit do
      puts "#at_exit callback reached!"
      # list all subscribers and stop them
      Pubsub.new.client.list_subscriptions.each(&:stop)
    end

    # Start enqueing jobs
    load_jobs(interval, jobs_per_second, error_chance)

    # Block, letting processing threads continue in the background
    sleep
  end

  def load_jobs(interval, jobs_per_second, error_chance)
    time_passed = 0
    while time_passed < interval
      time_passed += 1
      jobs_per_second.times.each { GenericJob.perform_later(error_chance) }
      sleep(1)
      Pubsub.new.client.list_subscriptions.each(&:stop)
    end
  end
end

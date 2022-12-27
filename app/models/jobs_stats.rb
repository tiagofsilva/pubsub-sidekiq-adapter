class JobsStats
  @success_jobs = []
  @dead_jobs = []

  class << self
    attr_accessor :success_jobs, :dead_jobs, :total_jobs_count

    def add_dead_job(job)
      dead_jobs << job
    end

    def add_success_job(job)
      success_jobs << job
    end

    def set_total_jobs_count(count)
      @total_jobs_count = count
    end

    def display
      if success_jobs.size + dead_jobs.size == total_jobs_count
        sleep(total_jobs_count / 5)
        puts "Final Stats:"
        puts "Successful jobs (#{success_jobs.size}):"
        success_jobs.each { |j| puts JobPresenter.new(j).to_s }
        puts "\nMorgue (#{dead_jobs.size}):"
        dead_jobs.each { |j| puts JobPresenter.new(j).to_s }
      end
    end
  end
end
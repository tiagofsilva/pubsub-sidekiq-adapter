class JobPresenter
  def initialize(job_data)
    @job_data = job_data
  end

  def to_s
    "#{@job_data['job_class']}-#{@job_data['job_id']}"
  end
end
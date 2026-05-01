class ServiceResult
  attr_reader :error

  def self.success(**data)
    new(success: true, data: data)
  end

  def self.failure(code:, message:, details: nil, **extra)
    new(
      success: false,
      data: extra,
      error: { code: code, message: message, details: details }.compact
    )
  end

  def initialize(success:, data: {}, error: nil)
    @success = success
    @data = data
    @error = error
  end

  def success?
    @success
  end

  def halt?
    @data[:halt] == true
  end

  def idempotent_replay?
    halt? && success?
  end

  def [](key)
    @data[key]
  end

  def method_missing(name, *args, &block)
    return @data[name] if @data.key?(name)

    super
  end

  def respond_to_missing?(name, include_private = false)
    @data.key?(name) || super
  end
end

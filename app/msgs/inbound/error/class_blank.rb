# new_pgr

class Inbound::Error::ClassBlank

  attr_reader :inbound

  def initialize(inbound = nil)
    @inbound = inbound
  end

  def handle
    raise "NOT IMPLEMENTED: #{self.class}"
  end
end
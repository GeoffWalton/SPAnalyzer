class Empty
  def self.binding(obj)
    @_obj = obj
    super()
  end

  def self.method_missing(m, *args, &blk)
    @_obj.send(m, *args, &blk)
  end

  def self.methods(regular = nil)
    (super + @_obj.methods) - (super & @_obj.methods)
  end

  def self.respond_to?(*args)
    super || @_obj.respond_to?(*args)
  end
end
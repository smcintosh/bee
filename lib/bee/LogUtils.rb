module LogUtils
  def fatalAndRaise(msg)
    @logger.fatal(msg)
    raise msg
  end
end

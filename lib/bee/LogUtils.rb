module LogUtils
  def fatalAndRaise(msg)
    @logger.fatal(msg)
    raise msg
  end

  #replace "prefix" in "thefname" by "<root>"
  def rootify(thefname,prefix)
    
    if (thefname.start_with?(prefix))
      thefname=thefname.sub(prefix,"<root>")
    end
    
    return thefname
  end
  
end

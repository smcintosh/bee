module Bee
  class STraceLine
    attr_accessor :op
    attr_accessor :resultValue
    attr_accessor :lineNumber
    attr_accessor :pid
    attr_accessor :data
    attr_accessor :parms

    include LogUtils

    def initialize(line, lineNumber, logger)
      @lineNumber = lineNumber
      @logger = logger

      fields = /^([0-9]+) +(.+)$/.match(line)
      if (!fields)
        fatalAndRaise("Illegal input '#{line}' [Line number: #{lineNumber}]")
      end

      @pid = fields[1].to_i
      @data = fields[2]

      parseParameters()

      @logger.debug("[#{line}]--[#{fields[1]}]--[#{fields[2]}]")

      (@op, @resultValue) = parseOperationType()

      @logger.debug("Operation: [#{@op}]--[#{@resultValue}]")
    end

    def parseParameters
      if (@data =~ /^[a-zA-Z_][_a-zA-Z0-9]+\((.+)\)\s+=\s+.+$/) 
        toParse = $1;
        toParse.gsub! '\\,', '<COLON>'
        @parms = toParse.split(', ');
      end
    end

    def parseOperationType
      resultValue = nil
      result = /^.+ = ([0-9\-\+]+)[^=]*$/.match(@data);
      if (result) 
        resultValue = result[1]
      end

      if (@data =~ /^(\w+)/) 
        op = $1;
      elsif (@data =~ /\+\+\+ exited with ([0-9]+) \+\+\+$/) 
        op = 'exited'
        resultValue = $1
      elsif (@data =~ /^<\.\.\. (\w+)/) 
        #op = $1 + "-cont"
        fatalAndRaise("Encountered unexpected operation in #{@data}")
      else 
        op = "XXXX-" + @data;
        @logger.warn("Unrecognized operation type treated as #{op}")
      end
      return op, resultValue
    end

    def exitGroup?
      return (@op == 'exit_group')
    end

    def execType?
      return (@op == 'execve')
    end

    def open?
      return (@op == 'open')
    end

    def unlink?
      return (@op == 'unlink')
    end

    def chdir?
      return (@op == 'chdir')
    end

    def rename?
      return (@op == 'rename')
    end

    def forkType?
      return (@op == 'vfork' or @op == 'clone')
    end
  end

  class STraceFile
    attr_accessor :taskid
    attr_accessor :filename
    attr_accessor :defaultDir
    attr_accessor :currentDir
    attr_accessor :op
    attr_accessor :mode
    attr_accessor :timeStamp
    attr_accessor :originalName

    include LogUtils

    def initialize(task, filename, op, timeStamp, mode, defaultDir)

      filename.sub!(/^"/,'')
      filename.sub!(/"$/,'')

      @originalName = filename
      @taskid = task.taskid
      @defaultDir = defaultDir
      @currentDir = task.currentDir
      @op = op
      @timeStamp = timeStamp;
      @mode = mode
      @filename = fixFilename(filename)
    end

    def cleanDir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def cleanCurrentDir
      return cleanDir(currentDir)
    end

    def fixFilename(f)

      if not @currentDir =~ /^\//
        # this function does not work with relative directories, period
        # because expand_path will use the current directory in the local computer to do it
        unless f =~ /^\//
          fatalAndRaise("directory of File should be absolute file [#{f}] currentDir [#{@currentDir}]")
        end
      end

      # if directory is absolute, clean it up (remove relative references
      # if directory is relative, make absolute
      # then remove directory
      f = File.expand_path(f, @currentDir)
      f = cleanDir(f)
      return f
    end

    def printFile
      puts "File [#{filename}] taskid [#{taskid}] currentdir [#{currentDir}] operation [#{op}] timeStamp [#{@timeStamp}] mode [#{@mode.to_s}]"
    end
  end

  class STraceTask
    @@currentTask = 0

    attr_accessor :taskid
    attr_accessor :beginLine
    attr_accessor :endLine
    attr_accessor :exitValue
    attr_accessor :parentTask
    attr_accessor :parentPid
    attr_accessor :pid
    attr_accessor :currentDir
    attr_accessor :beginDir
    attr_accessor :defaultDir

    include LogUtils

    def initialize(pid, lineNumber, defaultDir, logger)
      @logger = logger

      # assertions
      unless (defaultDir =~ /^\//)
        fatalAndRaise("parameter defaultDir should be absolute [#{defaultDir}]")
      end

      @taskid = @@currentTask
      @@currentTask = @@currentTask + 1
      @beginLine = lineNumber
      @pid = pid

      @defaultDir = defaultDir
    end

    def setExit(e)
      @exitValue = e.resultValue
      @endLine = e.lineNumber
    end

    def setExitUsingParm(pline)
      @exitValue = pline.parms[0]
      @endLine = pline.lineNumber
    end

    def setCommand(command)
      command.sub!(/^"/,'')
      command.sub!(/"$/,'')

      @command = command
    end

    def cleanDir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def cleanCurrentDir
      return cleanDir(currentDir)
    end

    def cleanBeginDir
      return cleanDir(currentDir)
    end

    def setCurrentDir(currentDir)

      # assert that the new directory is absolute

      currentDir = currentDir.sub(/^"/,'')
      currentDir = currentDir.sub(/"$/,'')

      if not currentDir =~ /^\//
        currentDir = File.expand_path(currentDir, @defaultDir)
        @logger.warn("Converted from relative to absolute path in setcurrent directory: [#{currentDir}]")
      end

      if (not @beginDir) 
        @beginDir = currentDir
      end
      @currentDir = currentDir
    end

    def setParent(parentTask,parentPid)
      @parentTask = parentTask
      @parentPid = parentPid
    end

    def command
      if @command
        return fixFilename(@command)
      else
        return @command
      end
    end

    def printTask()
      parentTask = @parentTask 
      parentPid = @parentPid
      if not parentTask 
        parentTask = ''
        parentPid = ''
      end
      puts "   task " + @taskid.to_s + " with pid " + @pid.to_s + " parent Task " + parentTask.to_s + "  parent pid " + parentPid.to_s + " command  [#{@command.inspect}] currentDir [#{@currentDir}]"
      if (@beginLine) 
        puts "        starts at " + @beginLine.to_s 
      end
      if (@endLine) 
        puts "        ends at " + @endLine.to_s + " exit value " + @exitValue.to_s
      end
    end

    #XXXXXXXXXXXXXXXXXXXXXXXXXXX
    # these are cloned!!! I need to learn how to refactor them
    def cleanDir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def fixFilename(f)

      if not @currentDir =~ /^\//
        # this function does not work with relative directories, period
        # because expand_path will use the current directory in the local computer to do it
        unless f =~ /^\//
          fatalAndRaise("directory of File should be absolute file [#{f}] currentDir [#{@currentDir}]") 
        end
      end

      # if directory is absolute, clean it up (remove relative references)
      # if directory is relative, make absolute
      # then remove directory
      f = File.expand_path(f, @currentDir)
      f = cleanDir(f)
      return f
    end
  end
end

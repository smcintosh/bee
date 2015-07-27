module Bee
  class STraceParser

    include LogUtils

    def initialize(traceFileName, executionPath, logger)
      @traceFileName = traceFileName

      @executionPath = executionPath.gsub(/\/$/,'')
      @completedTasks = Array.new
      @currentTasks = Hash.new
      @saveUnfinished = Hash.new
      @files = Array.new
      @currLine = -1;
      @logger = logger
      @noneCompleted = true
    end

    def create_task_if_needed(line)
      if (line =~ /([0-9]+)/)
        create_task_if_needed_pid($1)
      else
        fatalAndRaise("Unable top parse input line [#{line}]")
      end
    end

    def create_task_if_needed_pid(pid)
      thisPid = pid.to_i
      # is this a new task
      if (!@currentTasks[thisPid])
        @logger.info("New task #{thisPid}")
        @currentTasks[thisPid] = STraceTask.new(thisPid, @currLine, @executionPath, @logger)
        if (@currentTasks.length == 1 and @noneCompleted)
          @currentTasks[thisPid].setCurrentDir(@executionPath)
          @noneCompleted = false
        end
      end
    end

    def unfinished?(line)
      rtn = false

      if (line =~ /([0-9]+)(.+) <unfinished \.\.\.>$/)
        if (@saveUnfinished[$1.to_i])
          fatalAndRaise("Continuation for line #{$1} already in progress")
        end

        @saveUnfinished[$1.to_i] = $2
        rtn = true
      end

      return rtn
    end

    def check_if_continuation(line)
      # deal with incomplete lines
      if (line =~ /([0-9]+)(.+ )resumed> (.*)$/)
        line = $1 + @saveUnfinished[$1.to_i] + $3
        @saveUnfinished.delete($1.to_i)
      end

      return line
    end

    def process_file_rename(pline)
      thisTask = @currentTasks[pline.pid];
      if (pline.parms.length != 2)
        fatalAndRaise("Rename has unexpected number of parameters #{pline.data}")
      end

      @files.push(STraceFile.new(thisTask, pline.parms[0],'rename-in', @currLine,[], @executionPath))
      @files.push(STraceFile.new(thisTask, pline.parms[1],'rename-out',@currLine,[], @executionPath))
    end

    def process_file(pline, op, mode)
      thisTask = @currentTasks[pline.pid];
      @files.push(STraceFile.new(thisTask, pline.parms[0], op, @currLine, mode, @executionPath))
    end

    def process_line(pline)
      thisTask = @currentTasks[pline.pid]

      rtn = :cont

      if (pline.exitGroup?)
        thisTask.setExitUsingParm(pline)
        @completedTasks.push(@currentTasks.delete(pline.pid))
        rtn = :task

      elsif (pline.forkType?)
        # find task id of the parent
        childId = (pline.resultValue).to_i
        if (!@currentTasks[childId])
          create_task_if_needed_pid(childId)
        end

        @currentTasks[childId].setParent(thisTask.taskid, pline.pid)
        @currentTasks[childId].setCurrentDir(thisTask.currentDir)

      elsif (pline.execType?)
        if (pline.parms.nil? or pline.parms.length == 0)
          fatalAndRaise("We could not parse the parameters [#{pline.data}]")
        end

        thisTask.setCommand(pline.parms[0])

      elsif (pline.chdir? and pline.resultValue.to_i == 0)
        thisTask.setCurrentDir(pline.parms[0])

      # file related
      elsif (pline.open? and pline.resultValue.to_i >= 0)
        mode = pline.parms[1].split('|');

        rtn = :file
        if (mode.include?("O_DIRECTORY"))
          process_file(pline, 'directory-scan', mode)
        elsif (mode.include?("O_RDONLY"))
          process_file(pline, 'open-read-only', mode)
        elsif (mode.include?("O_WRONLY"))
          process_file(pline, 'open-write-only', mode)
        elsif (mode.include?("O_RDWR"))
          process_file(pline, 'open-read-write', mode)
        else
          fatalAndRaise("This is a mode we do not recognize #{mode.inspect}")
        end

      elsif (pline.unlink? and  pline.resultValue.to_i == 0)
        rtn = :file
        process_file(pline, 'unlink',[])

      elsif (pline.rename?  and  pline.resultValue.to_i == 0)
        rtn = :file_rename
        process_file_rename(pline)

      end

      return rtn
    end

    def each
      @currLine = 0
      #max = 0
      total_cnt = %x{wc -l #{@traceFileName}}.split.first.to_i
      cnt = 0
      avg_time = 0

      File.foreach(@traceFileName) do |line|
        @currLine += 1
        # do this so we can get some profiling output
        #if (@currLine >= max)
        #  return
        #end
        @logger.info("current #{sprintf("%10d",@currLine)}") if @currLine % 50000 == 0;
        if (@currLine % 10000 == 0)
          puts "Row: #{@currLine}/#{total_cnt}"
          #puts "avg_time: #{avg_time}"
          #puts "completedTasks: #{@completedTasks}, \
          #      currentTasks: #{@currentTasks}, saveUnfinished: #{@saveUnfinished}, \
          #      files: #{@files}"
        end

        # skip this, we have already handled it and the pid does not exist any more
        next if line =~ /^\d+ \+\+\+ exited with \d+ \+\+\+$/

        # as soon as we see a pid, we create a task
        create_task_if_needed(line)

        next if unfinished?(line)

        line = check_if_continuation(line)

        # now process the line
        pline = STraceLine.new(line, @currLine, @logger)
        if (!pline.pid)
          fatalAndRaise("Unable to parse pid from line #{@currLine}")
        end

        #start = Time.now
        code = process_line(pline)
        case code
        when :file
          yield :file, @files.pop

        when :file_rename
          yield :file, @files.pop
          yield :file, @files.pop

        when :task
          yield :task, @completedTasks.pop
          nil

        when :cont
          next

        else
          fatalAndRaise("Unrecognized return code #{code} from process_line()")
        end
        #finish = Time.now
        #avg_time = (avg_time+(finish-start))/2
      end
    end
  end
end

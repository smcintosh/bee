require 'uri'

module Bee
  class Trace_Line
    attr_accessor :op
    attr_accessor :resultValue
    attr_accessor :lineNumber
    attr_accessor :pid
    attr_accessor :data
    attr_accessor :parms

    def initialize(line, lineNumber)
      @lineNumber = lineNumber
      fields = /^([0-9]+) +(.+)$/.match(line)
      if (not fields) 
        raise "Illegal input in trace line [#{line}]";
      end
      @pid = fields[1].to_i
      @data = fields[2]
      Parse_Parameters()
      #    puts "[#{line}]--[#{fields[1]}]--[#{fields[2]}]"
      (@op, @resultValue) = Parse_Operation_Type()
      #    puts "Operation: [#{@op}]--[#{@resultValue}]"
    end

    def Parse_Parameters()
      if (@data =~ /^[a-zA-Z_][_a-zA-Z0-9]+\((.+)\)\s+=\s+.+$/) 
        toParse = $1;
        toParse.gsub! '\\,', '<COLON>'
        @parms = toParse.split(', ');
      end
    end

    def Parse_Operation_Type()
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
        op = $1 + "-cont"
        raise "This should not happen any more"
      else 
        op = "XXXX-" + @data;
      end
      return op, resultValue
    end

    def exit_group?()
      return (@op == 'exit_group');
    end

    def execType?()
      return (@op == 'execve');
    end

    def open?()
      return (@op == 'open');
    end

    def unlink?()
      return (@op == 'unlink');
    end

    def chdir?()
      return (@op == 'chdir');
    end

    def rename?()
      return (@op == 'rename');
    end

    def forkType?()
      return (@op == 'vfork' or @op == 'clone');
    end
  end

  class TraceFile
    attr_accessor :taskid
    attr_accessor :filename
    attr_accessor :defaultDir
    attr_accessor :currentDir
    attr_accessor :op
    attr_accessor :mode
    attr_accessor :timeStamp
    attr_accessor :originalName

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
      @filename = Fix_Filename(filename)
    end

    def Clean_Dir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def cleanCurrentDir
      return Clean_Dir(currentDir)
    end

    def Fix_Filename(f)

      if not @currentDir =~ /^\//
        # this function does not work with relative directories, period
        # because expand_path will use the current directory in the local computer to do it
        raise "directory of File should be absolute file [#{f}] currentDir [#{@currentDir}] " unless f =~ /^\//
      end

      # if directory is absolute, clean it up (remove relative references
      # if directory is relative, make absolute
      # then remove directory
      f = File.expand_path(f, @currentDir)
      f = Clean_Dir(f)
      return f
    end

    def printFile
      puts "File [#{filename}] taskid [#{taskid}] currentdir [#{currentDir}] operation [#{op}] timeStamp [#{@timeStamp}] mode [#{@mode.to_s}]"
    end
  end

  class Task
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

    def initialize(pid, lineNumber, defaultDir)

      # assertions

      raise "parameter defaultDir should be absolute [#{defaultDir}]" unless defaultDir =~ /^\//

      @taskid = @@currentTask
      @@currentTask = @@currentTask + 1
      @beginLine = lineNumber
      @pid = pid

      @defaultDir = defaultDir
    end

    def setExit(exit)
      @exitValue = exit.resultValue
      @endLine = exit.lineNumber
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

    def Clean_Dir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def cleanCurrentDir
      return Clean_Dir(currentDir)
    end

    def cleanBeginDir
      return Clean_Dir(currentDir)
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
        return Fix_Filename(@command)
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
    def Clean_Dir(dir)
      return dir.sub(/^#{@defaultDir}\/?/,'')
    end

    def Fix_Filename(f)

      if not @currentDir =~ /^\//
        # this function does not work with relative directories, period
        # because expand_path will use the current directory in the local computer to do it
        raise "directory of File should be absolute file [#{f}] currentDir [#{@currentDir}] " unless f =~ /^\//
      end

      # if directory is absolute, clean it up (remove relative references)
      # if directory is relative, make absolute
      # then remove directory
      f = File.expand_path(f, @currentDir)
      f = Clean_Dir(f)
      return f
    end
  end

  class Parser
    def initialize(traceFileName, executionPath)
      @traceFileName = traceFileName

      # remove trailing directlry
      executionPath.gsub(/\/$/,'') 

      @executionPath = executionPath
      @completedTasks = Array.new
      @currentTasks = Hash.new
      @saveUnfinished = Hash.new
      @files = Array.new
      @currLine = -1;
    end

    def create_task_if_needed(line)
      if (line =~ /([0-9]+)/) 
        create_task_if_needed_pid($1)
      else
        raise "Unable top parse input line [#{line}]"
      end
    end

    def create_task_if_needed_pid(pid)
      thisPid = pid.to_i
      # is this a new task
      if (@currentTasks[thisPid] == nil)
        #      puts "Created task #{thisPid} "
        @currentTasks[thisPid] = Task.new(thisPid, @currLine, @executionPath)
        if (@currentTasks.length == 1 and
            @completedTasks.length == 0) 
          @currentTasks[thisPid].setCurrentDir(@executionPath)
        end
      end
    end

    def unfinished?(line)
      if (line =~ /([0-9]+)(.+) <unfinished \.\.\.>$/) 
        raise "continuation line already in progress" if @saveUnfinished[$1.to_i] != nil;
        @saveUnfinished[$1.to_i] = $2
        return true;
      end
      return false;
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
        raise "rename wrong parameters #{pline.data}"
      end
      @files.push(TraceFile.new(thisTask, pline.parms[0],'rename-in', @currLine,[], @executionPath))
      @files.push(TraceFile.new(thisTask, pline.parms[1],'rename-out',@currLine,[], @executionPath))
    end

    def process_file(pline, op, mode)
      thisTask = @currentTasks[pline.pid];
      @files.push(TraceFile.new(thisTask, pline.parms[0], op, @currLine, mode, @executionPath))
    end

    def process_line(pline)

      thisTask = @currentTasks[pline.pid];

      # process tasks

      # this code seems to be irrelevant now
      #    if (pline.op == 'exited')
      #      thisTask.setExit(pline)
      #      @completedTasks.push(@currentTasks.delete(pline.pid))

      if (pline.exit_group?)
        thisTask.setExitUsingParm(pline)
        @completedTasks.push(@currentTasks.delete(pline.pid))
      elsif (pline.forkType?)
        # find task id of the parent
        childId = (pline.resultValue).to_i
        if (@currentTasks[childId] == nil) 
          create_task_if_needed_pid(childId)
        end
        @currentTasks[childId].setParent(thisTask.taskid, pline.pid)
        @currentTasks[childId].setCurrentDir(thisTask.currentDir)
      elsif (pline.execType?)
        raise "we could not parse the parameters [#{pline.data}]" if pline.parms.nil? or pline.parms.length == 0;
        thisTask.setCommand(pline.parms[0])
      elsif (pline.chdir? and pline.resultValue.to_i == 0) 
        thisTask.setCurrentDir(pline.parms[0])
        # file related
      elsif (pline.open? and  pline.resultValue.to_i >= 0) 
        mode = pline.parms[1].split('|');
        if (mode.include?("O_DIRECTORY")) 
          process_file(pline, 'directory-scan', mode)        
        elsif (mode.include?("O_RDONLY")) 
          process_file(pline, 'open-read-only', mode)
        elsif (mode.include?("O_WRONLY")) 
          process_file(pline, 'open-write-only', mode)
        elsif (mode.include?("O_RDWR")) 
          process_file(pline, 'open-read-write', mode)
        else 
          raise "This is a mode we do not recognize #{mode.inspect}"
        end
      elsif (pline.unlink? and  pline.resultValue.to_i == 0) 
        process_file(pline, 'unlink',[])
      elsif (pline.rename?  and  pline.resultValue.to_i == 0) 
        process_file_rename(pline)
      end
    end

    def parse
      @currLine = 0
      File.foreach(@traceFileName) do |line|
        @currLine = @currLine + 1
        @logger.info("current #{sprintf("%10d",@currLine)}") if @currLine % 50000 == 0;

        # skip this, we have already handled it and the pid does not exist any more
        next if line =~ /^\d+ \+\+\+ exited with \d+ \+\+\+$/;

        # as soon as we see a pid, we create a task
        create_task_if_needed(line)

        next if unfinished?(line)

        line = check_if_continuation(line)

        # now process the line
        pline = Trace_Line.new(line, @currLine)
        if (pline.pid == nil) 
          raise @currLine + " not able to parse pid"
        end
        process_line(pline)
      end

      # Sort the completed tasks by taskid
      @completedTasks.sort_by! {|task| task.taskid}

      # Sanity check
      if (@currentTasks.length > 0 )
        @currentTasks.each do |key, task|
          if (task)
            puts "#{key} -> "
            task.printTask()
          end
        end

        @logger.error("This code should not be executed: it means some tasks didn't end properly (or our code is faulty)")
      end

    rescue Exception => e
      raise "--------Failing at #{@currLine}"
      # now process the instruction

      #      return if currLine > 4000
    end

    def each_task
      @completedTasks.each do |task|
        yield task
      end
    end

    def each_file
      @files.each do |file|
        yield file
      end
    end
  end

  class STraceLoader < Loader
    def initialize(config)
      fname = config.get(:strace_file)
      super(fname, config)
      @parser = Parser.new(fname, config.get(:build_home))
      @parser.parse()

      @logger.info("Finished parsing.. exporting")

      pkgmapfile = config.get(:pkgmap_file)
      addPkgMap(pkgmapfile) if (pkgmapfile)

      @childparent = {}
    end

    def addPkgMap(mapfile)
      @pkgmap = {}

      File.foreach(mapfile) do |line|
        fname,res_fname,pkg = line.strip.split(",")
        @pkgmap[fname] = pkg
      end
    end

    # TODO: Need to implement this...
    def isJunkTask(task)
      return false
    end

    def lookup_task(tid)
      tid = @childparent[tid] ? @childparent[tid] : tid 
      task = @writer.getNode(:nid, tid)
      if (!task)
        raise "Could not locate relation with task id #{tid}"
      end

      return task
    end

    def handle_task(task)
      # N;process;5608;/usr/bin/msgfmt;<root>/po;execve("/usr/bin/msgfmt", ["/usr/bin/msgfmt", "-c", "-o", "./pt_BR.gmo", "pt_BR.po"], [/* 22 vars */]) = 0
      return if (isJunkTask(task))

      if (task.parentTask)
        pnode = lookup_task(task.parentTask)

        pcommand = @writer.getProperty(pnode, :command)
        flattens = @config.get(:strace_flatten)
        flattens.size.times do |i|
          if (!flattens[i].start_with?('/'))
            flattens[i] = "/#{flattens[i]}"
          end
        end
        
        if (pcommand and pcommand.downcase.end_with?(*flattens))
          @childparent[task.taskid] = @writer.getProperty(pnode, :nid)
        end
      end

      if (!@childparent[task.taskid])
        myNode = @writer.addNode(task.taskid) do |n|
          @writer.addProperty(n, "nid", task.taskid)
          @writer.addProperty(n, "command", task.command)
          @writer.addProperty(n, "dir", task.currentDir)
          @writer.addLabel(n, :process)
        end
        
        if (task.parentTask)
          @writer.addEdge("child", pnode, myNode) do |e|
          end
        end
      end
    end

    def isJunkFile(file)
      return (!file.filename or file.filename.empty?)
    end

    def handle_file(file)
      return if (isJunkFile(file))

      @logger.debug(file.filename)

      fname = file.filename
      internal = 0

      if (!file.filename.start_with?("/"))
        fname = "<root>/#{file.filename}"
        internal = 1
      end

      # N;file;<root>/src/.deps/xo-print.Po;<root>/src/.deps/xo-print.Po;in

      myfile = @writer.getNode(:nid, fname)
      if (!myfile)
        myfile = @writer.addNode(fname) do |n|
          @writer.addProperty(n, "nid", fname)
          @writer.addProperty(n, "internal", internal)
          @writer.addLabel(n, :file)
        end
      end

      addNecessaryEdges(translate_op(file.op),
                        myfile,
                        lookup_task(file.taskid),
                        fname)
    end

    def addNecessaryEdges(op, file, task, fname)
      if (@pkgmap and @pkgmap[fname])
        pkg = @pkgmap[fname]
        
        # get/add node for package
        pkgnode = @writer.getNode(:nid, pkg)
        if (!pkgnode)
          pkgnode = @writer.addNode(pkg) do |n|
            @writer.addProperty(n, "nid", pkg)
            @writer.addLabel(n, :pkg)
          end
        end
            
        # add contains edge from file to package
        @writer.addEdge("contains", pkgnode, file) do |e|
        end

        # add edge to package
        file = pkgnode
      end

      if (op == "read")
        @writer.addEdge(op, file, task) do |e|
        end
      else
        @writer.addEdge(op, task, file) do |e|
        end
      end
    end

    def translate_op(op)
      rtn = nil
      case op
      when "directory-scan"
        rtn = "dirscan"
      when "open-read-only"
        rtn = "read"
      when "open-read-write", "open-write-only"
        rtn = "write"
      when "rename-in", "rename-out"
        rtn = "rename"
      when "unlink"
        rtn = "unlink"
      else
        raise "Unknown relation type #{op}"
      end

      return rtn
    end

    def load_hook
      i = 0
      @parser.each_task do |task|
        handle_task(task)
        i += 1
      end
      @logger.info("Exported #{i} tasks")

      i = 0
      @parser.each_file do |file|
        handle_file(file)
        i += 1
      end
      @logger.info("Exported #{i} files")
    end
  end
end

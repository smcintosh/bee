#!/usr/bin/env ruby

require 'rubygems'
require 'neo4j-core'
require 'sqlite3'
require 'uri'

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
      warn "Converted from relative to absolute path in setcurrent directory: [#{currentDir}]"
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
      warn("current #{sprintf("%10d",@currLine)}") if @currLine % 50000 == 0;

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

      warn "This code should not be executed: it means some tasks didn't end properly (or our code is faulty)"
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

# Abstract export behaviour
class Exporter
  def initialize(parser)
    @parser = parser
  end

  # Concrete classes need to implement this
  def handle_task(task)
    raise "Not implemented"
  end

  # Concrete classes need to implement this
  def handle_file(file)
    raise "Not implemented"
  end

  def start_export
  end

  def end_export
  end

  def export
    start_export()

    i = 0
    @parser.each_task do |task|
      handle_task(task)
      i = i + 1
    end
    warn("Exported #{i} tasks")
    i = 0
    @parser.each_file do |file|
      handle_file(file)
      i = i + 1
    end
    warn("Exported #{i} files")
    end_export()
  end
end

# neo4j exporter
class Neo4jExporter < Exporter
  def initialize(parser)
    super(parser)
    Neo4j::Session.open(:server_db, "http://localhost:7474")
  end

  def handle_task(task)
	  # N;process;5608;/usr/bin/msgfmt;<root>/po;execve("/usr/bin/msgfmt", ["/usr/bin/msgfmt", "-c", "-o", "./pt_BR.gmo", "pt_BR.po"], [/* 22 vars */]) = 0
    myNode = Neo4j::Node.create({nid: task.taskid, command: task.command, dir: task.currentDir}, :process, :node)

    if (task.parentTask)
      nodes = Neo4j::Label.find_nodes(:node, :nid, task.parentTask)
      if (nodes.count != 1)
        raise "Could not locate parent task #{task.parentTask}"
      end

      Neo4j::Relationship.create("child", nodes.peek, myNode)
    end
  end

  def handle_file(file)
    return if (!file.filename or file.filename.empty?)
    warn file.filename

    fname = file.filename.start_with?("/") ? file.filename : "<root>/#{file.filename}"

    # N;file;<root>/src/.deps/xo-print.Po;<root>/src/.deps/xo-print.Po;in
    nodes = Neo4j::Label.find_nodes(:node, :nid, fname)
    if (nodes.count == 1)
      myNode = nodes.peek
    elsif (nodes.count == 0)
      myNode = Neo4j::Node.create({nid: fname, internal: (fname.start_with?("<root>") ? 1 : 0)}, :file, :node)
    else
      raise "Graph has entered a state where the same file appears multiple times"
    end

    relations = Neo4j::Label.find_nodes(:node, :nid, file.taskid)
    if (relations.count != 1)
      raise "Could not locate relation with task id #{file.taskid}"
    end

    op = translate_op(file.op)
    case op
    when "read"
      Neo4j::Relationship.create(op, myNode, relations.peek)
    else
      Neo4j::Relationship.create(op, relations.peek, myNode)
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
end

class DBExporter < Exporter

  def initialize(parser, filename)
    warn "Database File  [#{filename}] does not exist Creating.." if not File.file?(filename);
    @db = SQLite3::Database.open filename
    createTableTasks()
    createTableFiles()
    super(parser)
  end

  def start_export
    @db.transaction()
  end

  def end_export
    @db.commit()
    @db.close()
  end

  def handle_task(task)
    @db.execute("insert into tasks(taskid, pid, command, line_begin, line_end, 
                                   exit_value, parent_task, parent_pid, dir_begin, dir_end) 
                 values (?,?,?,?,?,
                         ?,?,?,?,?)",
               task.taskid, task.pid, task.command, task.beginLine, task.endLine, 
               task.exitValue, task.parentTask, task.parentPid, task.cleanBeginDir, task.cleanCurrentDir)
  end

  def handle_file(file)
#    file.printFile()

#    puts("#{file.filename}, #{file.taskid}, #{file.timeStamp}, #{file.op}, #{file.mode}, [#{file.currentDir}][#{file.defaultDir}][#{file.cleanCurrentDir}]")

    @db.execute("insert into files(filename, taskid, timestamp, op, mode, allmodes, dir) 
                 values (?,?,?,?,?,?,?)",
               file.filename, file.taskid, file.timeStamp, file.op, file.mode[0], file.mode.join(';'), file.cleanCurrentDir)
  end


  def createTableTasks
    @db.execute("DROP TABLE IF EXISTS Tasks;")
    @db.execute "
CREATE TABLE IF NOT EXISTS
Tasks(
      taskid INTEGER PRIMARY KEY, 
      pid integer,
      command TEXT,
      line_begin intger,
      line_end integer,
      exit_value integer,
      parent_task integer,
      parent_pid   integer,
      dir_begin text,
      dir_end   text
      );"
  end
  
  def createTableFiles
    @db.execute("DROP TABLE IF EXISTS Files;")
    @db.execute "
CREATE TABLE IF NOT EXISTS
Files( 
      filename text,
      taskid INTEGER, 
      timestamp integer,
      op TEXT,
      mode TEXT,
      allmodes TEXT,
      dir TEXT
      );"
  end


end

class PrintExporter < Exporter
  def handle_task(task)
    task.printTask
  end

  def handle_file(file)
    file.printFile
  end
end

begin
  filename = ARGV[0]
  executionPath = ARGV[1]
  dbName = ARGV[2]

  if filename.to_s == "" or executionPath.to_s == "" or dbName.to_s == ""
    raise "Usage #{$0} <traceFile> <defaultPath> <sqlDB|print>" 
  end

  parser = Parser.new(filename, executionPath)

  parser.parse()
  warn "Finished parsing.. exporting"


  if (dbName == 'print') 
      exporter = PrintExporter.new(parser)
  elsif (dbName == 'neo4j')
      exporter = Neo4jExporter.new(parser)
  else
    exporter = DBExporter.new(parser, dbName)
  end
  exporter.export

end

require 'uri'

module Bee
  class STraceLoader < Loader

    include LogUtils

    def initialize(config)
      fname = config.get(:strace_file)
      super(fname, config)
      @parser = STraceParser.new(fname, config.get(:build_home), @logger)

      pkgmapfile = config.get(:pkgmap_file)
      addPkgMap(pkgmapfile) if (pkgmapfile)

      @taskqueue = {}
      @filequeue = {}

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

      fatalAndRaise("Could not locate relation with task id #{tid}") if (!task)

      return task
    end

    def handle_tasks_with_parents(task)
      # Add yourself
      handle_task(task)
      @t += 1

      # Process the files associated with this task
      if (@filequeue[task.taskid])
        @filequeue[task.taskid].each do |f|
          handle_file(f)
          @f += 1
        end
        @filequeue[task.taskid].clear
      end

      # Process all children
      if (@taskqueue[task.taskid])
        @taskqueue[task.taskid].each do |t|
          handle_tasks_with_parents(t)
        end
        @taskqueue[task.taskid].clear
      end
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
          @writer.addProperty(n, "dir", rootify(task.currentDir,@config.get(:build_home)))
          @writer.addLabel(n, :process)
          @writer.addLabel(n, :strace)
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

    def is_package_file(fname)
      return (@pkgmap and @pkgmap[fname])
    end

    def handle_file(file)
      return if (isJunkFile(file))
      # TODO add a node for the package to the graph... all package info is lost now
      return if (is_package_file(file.filename))

      @logger.debug(file.filename)

      fname = file.filename
      internal = 0

      if (!file.filename.start_with?("/"))
        fname = "<root>/#{file.filename}"
        internal = 1
      else
        #for MAKAO nodes
        fname=rootify(fname,@config.get(:build_home))
        if (fname.start_with?("<root>"))
          internal = 1
        end
      end

      # N;file;<root>/src/.deps/xo-print.Po;<root>/src/.deps/xo-print.Po;in

      myfile = @writer.getNode(:nid, fname)
      if (!myfile)
        myfile = @writer.addNode(fname) do |n|
          @writer.addProperty(n, "nid", fname)
          @writer.addProperty(n, "internal", internal)
          @writer.addLabel(n, :file)
          @writer.addLabel(n, :strace)
        end
      end

      addNecessaryEdges(translate_op(file.op),
                        myfile,
                        lookup_task(file.taskid),
                        fname)
    end

    def addNecessaryEdges(op, file, task, fname)
      if (is_package_file(fname))
        pkg = @pkgmap[fname]
        
        # get/add node for package
        pkgnode = @writer.getNode(:nid, pkg)
        if (!pkgnode)
          pkgnode = @writer.addNode(pkg) do |n|
            @writer.addProperty(n, "nid", pkg)
            @writer.addLabel(n, :pkg)
            @writer.addLabel(n, :strace)
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
        fatalAndRaise("Unknown relation type #{op}")
      end

      return rtn
    end

    def load_hook
      @logger.info("=== STARTING STraceLoader ===")

      @t = 0
      @f = 0
      @parser.each do |type, item|
        case type
        when :task
          if (item.parentTask and !@writer.getNode(:nid, item.parentTask))
            @taskqueue[item.parentTask] = [] if (!@taskqueue[item.parentTask])
            @taskqueue[item.parentTask] << item
          else
            handle_tasks_with_parents(item)
          end

        when :file
          # Queue files for where the task is finished
          # unless it's a junk or package file
          if (isJunkFile(item) || is_package_file(item.filename))
            next
          end
          @filequeue[item.taskid] = [] if (!@filequeue[item.taskid])
          @filequeue[item.taskid] << item
          @logger.info("Queueing file: " + rootify(item.filename,@config.get(:build_home)) + " for taskid: " + item.taskid.to_s)

        else
          fatalAndRaise("Unrecognized strace item type #{item.type}")

        end
      end

      @logger.info("Exported #{@t} tasks and #{@f} files")
      @logger.info("=== FINISHED STraceLoader ===")
    end
  end
end

require 'uri'

module Bee
  class STraceLoader < Loader
    def initialize(config)
      fname = config.get(:strace_file)
      super(fname, config)
      @parser = STraceParser.new(fname, config.get(:build_home), @logger)

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
          @writer.addProperty(n, :node_from, "strace")
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
          @writer.addProperty(n, :node_from, "strace")
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
            @writer.addProperty(n, :node_from, "strace")
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
      @logger.info("=== STARTING STraceLoader ===")

      t = 0
      f = 0
      @parser.each do |type, item|
        case type
        when :task
          handle_task(item)
          t += 1
        when :file
          handle_file(item)
          f += 1
        else
          msg = "Unrecognized strace item type #{item.type}"
          @logger.fatal(msg)
          raise msg
        end

      @logger.info("Exported #{t} tasks and #{f} files")

      @logger.info("=== FINISHED STraceLoader ===")
    end
  end
end

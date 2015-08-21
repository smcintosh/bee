require 'uri'

module Bee
  class STraceToCsvLoader < Loader

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
         # TODO do we really need this? it is a memory hog... probably it is better to just print the names for the dependencies and
        # replace them using a bash script later?
      @tasks = Hash.new


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
      #task = @writer.getNodeId(tid)
      task = @tasks[tid]

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
        pcommand = pnode.command
        flattens = @config.get(:strace_flatten)
        flattens.size.times do |i|
          if (!flattens[i].start_with?('/'))
            flattens[i] = "/#{flattens[i]}"
          end
        end

        if (pcommand and pcommand.downcase.end_with?(*flattens))
          @childparent[task.taskid] = pnode.taskid
        end
      end

      if (!@childparent[task.taskid])
        node = @writer.addNode(task.taskid, "strace", task.currentDir, task.command)
        node.taskid = task.taskid
        node.command = task.command
        node.dir = task.currentDir

        @tasks[task.taskid] = node
        if (task.parentTask)
          # @writer.addEdge(pnode.taskid, node.taskid, "child")
          # do nothing for now with child relations
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
      #return if (is_package_file(file.filename))
      @logger.debug(file.filename)

      fname = file.filename
      internal = 0

      if (!file.filename.start_with?("/"))
        fname = "<root>/#{file.filename}"
        internal = 1
      end

      # N;file;<root>/src/.deps/xo-print.Po;<root>/src/.deps/xo-print.Po;in
      # check if we have an existing node for this file
      myfile = @writer.getFileNode(fname)
      if (!myfile)
        myfile = @writer.addNode(fname, "strace", "", "", fname)
        myfile.fname = fname
        myfile.internal = internal
      end

      addNecessaryEdges(translate_op(file.op),
                        myfile,
                        lookup_task(file.taskid),
                        fname)
    end

    def addNecessaryEdges(op, file, task, fname)
      # FIX THIS: package lifting is broken in csv import
      #if (is_package_file(fname))
      #  pkg = @pkgmap[fname]

        # get/add node for package
      #  pkgnode = @writer.getNode(pkg)
      #  if (!pkgnode)
      #    pkgnode = @writer.addNode(pkg, "strace", "","",pkg=pkg)
      #    pkgnode.pkg = pkg
      #  end

        # add contains edge from file to package
      #  @writer.addEdge(pkgnode.pkg, fname, "contains")

        # add edge to package
      #  file = pkgnode
      #end

      filenode = @writer.getFileNode(fname).name
      case op
      when "read"
        # use task.taskid here because addEdge gets the node using taskid
        @writer.addEdge(filenode, task.taskid, op)
      when "write"
        # use task.taskid here because addEdge gets the node using taskid
        @writer.addEdge(task.taskid, filenode, op)
      else
        @writer.addEdge(task.taskid, filenode, op)
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
      @logger.info("=== STARTING STraceToCsvLoader ===")

      @t = 0
      @f = 0
      @writer.loadNodes()
      @writer.setHeaders("strace")

      @parser.each do |type, item|
        case type
        when :task
          if (item.parentTask and !@tasks[item.parentTask])
            @taskqueue[item.parentTask] = [] if (!@taskqueue[item.parentTask])
            @taskqueue[item.parentTask] << item
          else
            handle_tasks_with_parents(item)
          end

       when :file
          # Queue files for where the task is finished
          # unless it's a junk or package file
          #if (isJunkFile(item) || is_package_file(item.filename))
          #  next
          #end
          @filequeue[item.taskid] = [] if (!@filequeue[item.taskid])
          @filequeue[item.taskid] << item
          @logger.info("Queueing file: " + item.filename + " for taskid: " + item.taskid.to_s)
        else
          fatalAndRaise("Unrecognized strace item type #{item.type}")

        end
      end

      @logger.info("Exported #{@t} tasks and #{@f} files")
      @logger.info("=== FINISHED STraceLoader ===")
    end
  end
end

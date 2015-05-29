module Bee
  class Autotools
    def junkfiles
      return ["makefile",
              "makefile_am",
              "makefile_in",
              "config_status",
              "configure",
              "configure_ac",
              "aclocal_m4",
              "_po"]
    end
  end
end

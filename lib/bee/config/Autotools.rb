module Bee
  class Autotools
    def junkfiles
      return ["makefile",
              "makefile_am",
              "makefile_in",
              "config_status",
              "config_h_in",
              "configure",
              "configure_ac",
              "aclocal_m4",
              "_po",
              "_plo"]
    end
  end
end

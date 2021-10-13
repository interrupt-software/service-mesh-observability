# This declares a job named "docs". There can be exactly one
# job declaration per job file.
job "docs" {
  # Run this job as a "service" type. Each job type has different
  # properties. See the documentation below for more examples.
  type = "service"

  # A group defines a series of tasks that should be co-located
  # on the same client (host). All tasks within a group will be
  # placed on the same host.
  group "fiver" {
    # Specify the number of these tasks we want.
    count = 1

    # network {
      # This requests a dynamic port named "http". This will
      # be something like "46283", but we refer to it via the
      # label "http".
    #   port "http" {}

      # This requests a static port on 443 on the host. This
      # will restrict this task to running once per host, since
      # there is only one port 443 on each host.
    #   port "https" {
    #     static = 443
    #   }
    # }

    # The service block tells Nomad how to register this service
    # with Consul for service discovery and monitoring.
    # service {
    #   # This tells Consul to monitor the service on the port
    #   # labelled "http". Since Nomad allocates high dynamic port
    #   # numbers, we use labels to refer to them.
    #   port = "http"

    #   check {
    #     type     = "http"
    #     path     = "/health"
    #     interval = "10s"
    #     timeout  = "2s"
    #   }
    # }

    # Create an individual task (unit of work). This particular
    # task utilizes a Docker container to front a web application.
    task "bashservice" {
       driver = "exec"

       config {
        command = "/usr/bin/bash /home/ubuntu/scripts/five-minutes.bash"
      }
    }
  }
}



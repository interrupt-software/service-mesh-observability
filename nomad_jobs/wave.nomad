job "wave" {
  datacenters = ["dc1"]

  group "wave" {
    task "wave" {
      driver = "docker"

      config {
        image = "voiselle/wave:v5"
        args = [ "300", "200", "15", "64", "4" ]
      }

      resources {
        memory = 400
        memory_max = 520
      }
    }
  }
}

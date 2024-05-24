locals {
  domain      = format("jupyterhub.%s", trimprefix("${var.subdomain}.${var.base_domain}", "."))
  domain_full = format("jupyterhub.%s.%s", trimprefix("${var.subdomain}.${var.cluster_name}", "."), var.base_domain)

  helm_values = [{
    jupyterhub = {
      proxy = {
        https = {
          enabled = true
        }
      }
      hub = {
        extraEnv = {
          OAUTH_TLS_VERIFY = "0"
        }
        config = {
          GenericOAuthenticator = {
            login_service      = "keycloak"
            client_id          = "${var.oidc.client_id}"
            client_secret      = "${var.oidc.client_secret}"
            oauth_callback_url = "https://${local.domain_full}/hub/oauth_callback"
            authorize_url      = "${var.oidc.oauth_url}"
            token_url          = "${var.oidc.token_url}"
            userdata_url       = "${var.oidc.api_url}"
            username_key       = "preferred_username"
            scope              = ["openid", "email", "groups"]
            userdata_params    = { state = "state" }
            claim_groups_key   = "groups"
            allowed_groups     = ["user", "modern-gitops-stack-admins"]
            admin_groups       = ["modern-gitops-stack-admins"]
          }
          JupyterHub = {
            admin_access        = true
            authenticator_class = "generic-oauth"
          }
        }
      }
      debug = {
        enabled = true
      }
      singleuser = {
        image = {
          name = "quay.io/jupyter/all-spark-notebook"
          tag  = "latest"
        }
        storage = {
          homeMountPath = "/home/jovyan/work"
        }
        extraEnv = {
          DB_ENDPOINT                = "${var.database.endpoint}"
          DB_USER                    = "${var.database.user}"
          DB_PASSWORD                = "${var.database.password}"
          MLFLOW_TRACKING_URI        = var.mlflow != null ? "http://${var.mlflow.endpoint}:5000" : null
          MLFLOW_S3_ENDPOINT_URL     = "http://${var.storage.endpoint}"
          AWS_ENDPOINT               = "http://${var.storage.endpoint}"
          AWS_ACCESS_KEY_ID          = "${var.storage.access_key}"
          AWS_SECRET_ACCESS_KEY      = "${var.storage.secret_access_key}"
          AWS_REGION                 = "eu-west-1",
          AWS_ALLOW_HTTP             = "true",
          AWS_S3_ALLOW_UNSAFE_RENAME = "true",
          RAY_ADDRESS                = var.ray != null ? "ray://${var.ray.endpoint}:10001" : null
        }
        profileList = [
          # {
          #   display_name = "DataScience",
          #   slug         = "datascience",
          #   description  = "CPU: 2 cores, RAM: 4Gi"
          #   default      = true,
          #   profile_options = {
          #     image = {
          #       display_name = "Image",
          #       choices = {
          #         pytorch = {
          #           display_name = "Data Science",
          #           default      = true,
          #           kubespawner_override = {
          #             image = "quay.io/jupyter/datascience-notebook:latest"
          #           }
          #         },
          #         tf = {
          #           display_name = "Spark",
          #           kubespawner_override = {
          #             image = "quay.io/jupyter/all-spark-notebook:latest"
          #           }
          #         }
          #       }
          #     }
          #   },
          #   kubespawner_override = {
          #     cpu_limit = 2,
          #     mem_limit = "4G",
          #   }
          # },
          # {
          #   display_name = "DataEngineer",
          #   slug         = "dataengineer",
          #   profile_options = {
          #     memory = {
          #       display_name = "Memory",
          #       choices = {
          #         "2Gi" = {
          #           display_name = "2GB",
          #           kubespawner_override = {
          #             mem_limit = "2G"
          #           }
          #         },
          #         "4Gi" = {
          #           display_name = "4G",
          #           kubespawner_override = {
          #             mem_limit = "4G"
          #           }
          #         }
          #       }
          #     },
          #     cpu = {
          #       display_name = "CPUs",
          #       choices = {
          #         "2" = {
          #           display_name = "2 CPUs",
          #           kubespawner_override = {
          #             cpu_limit     = 2,
          #             cpu_guarantee = 1.8,
          #           }
          #         },
          #         "4" = {
          #           display_name = "4 CPUs",
          #           kubespawner_override = {
          #             cpu_limit     = 4,
          #             cpu_guarantee = 3.5,
          #           }
          #         }
          #       }
          #     },
          #   },
          #   kubespawner_override = {
          #     image = "quay.io/jupyter/all-spark-notebook:latest",
          #   }
          # },
          {
            display_name = "Data Science",
            slug         = "datascience",
            description  = "CPU: 1 core, RAM: 2Gi"
            kubespawner_override = {
              image     = "quay.io/jupyter/datascience-notebook:latest",
              cpu_limit = 1,
              mem_limit = "2G",
            }
          },
          {
            display_name = "Data Engineer",
            slug         = "dataengineer",
            description  = "CPU: 1 core, RAM: 2Gi"
            kubespawner_override = {
              cpu_limit = 1,
              mem_limit = "2G",
            }
          }
        ]
      }
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer"                   = "${var.cluster_issuer}"
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          "traefik.ingress.kubernetes.io/router.tls"         = "true"
        }
        ingressClassName = "traefik"
        hosts = [
          local.domain,
          local.domain_full
        ]
        tls = [{
          secretName = "jupyterhub-ingres-tls"
          hosts = [
            local.domain,
            local.domain_full
          ]
        }]
      }
      cull = {
        every   = 300
        timeout = 1800
        maxAge  = 43200
      }
    }
  }]
}

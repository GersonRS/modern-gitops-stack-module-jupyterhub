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
        initContainers = [
          {
            name  = "git-clone-templates"
            image = "alpine/git"
            securityContext = {
              runAsUser    = 1000
              runAsGroup   = 1000
              runAsNonRoot = true
            }
            command = ["/bin/sh", "-c"]
            args = [
              "cd /tmp && git clone --branch=main https://github.com/GersonRS/jupyterhub-templates.git && cp -r jupyterhub-templates/templates/* /templates && cp -r jupyterhub-templates/extra-assets/* /extra-assets"
            ]
            volumeMounts = [
              {
                name      = "custom-templates"
                mountPath = "/templates"
              },
              {
                name      = "custom-templates-extra-assets"
                mountPath = "/extra-assets"
              }
            ]
          }
        ]
        extraVolumes = [
          {
            name     = "custom-templates"
            emptyDir = {}
          },
          {
            name     = "custom-templates-extra-assets"
            emptyDir = {}
          }
        ]
        extraVolumeMounts = [
          {
            name      = "custom-templates"
            mountPath = "/usr/local/share/jupyterhub/custom_templates"
          },
          {
            name      = "custom-templates-extra-assets"
            mountPath = "/usr/local/share/jupyterhub/static/extra_assets"
          }
        ]
        extraConfig = {
          templates = "c.JupyterHub.template_paths = ['/usr/local/share/jupyterhub/custom_templates/']"
        }
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
          AWS_REGION                 = "eu-west-1"
          AWS_ALLOW_HTTP             = "true"
          AWS_S3_ALLOW_UNSAFE_RENAME = "true"
          RAY_ADDRESS                = var.ray != null ? "ray://${var.ray.endpoint}:10001" : null
        }
        profileList = [
          {
            display_name = "Configure seu Ambiente"
            slug         = "jupyter-environment"
            description  = "Escolha os recursos e a imagem para seu servidor Jupyter"
            default      = true
            profile_options = {
              resources = {
                display_name = "Recursos do Servidor"
                choices = {
                  minimal = {
                    display_name = "Minimal"
                    description  = "Para tarefas leves e exploração de dados"
                    default      = true
                    kubespawner_override = {
                      cpu_guarantee = 0.5
                      cpu_limit     = 2
                      mem_guarantee = "2G"
                      mem_limit     = "4G"
                    }
                  }
                  standard = {
                    display_name = "Standard"
                    description  = "Ideal para análises e machine learning"
                    kubespawner_override = {
                      cpu_guarantee = 1
                      cpu_limit     = 4
                      mem_guarantee = "4G"
                      mem_limit     = "16G"
                    }
                  }
                  performance = {
                    display_name = "Performance"
                    description  = "Para modelos complexos e grandes datasets"
                    kubespawner_override = {
                      cpu_guarantee = 2
                      cpu_limit     = 8
                      mem_guarantee = "8G"
                      mem_limit     = "32G"
                    }
                  }
                }
              }
              image = {
                display_name = "Imagem do Container"
                choices = {
                  datascience = {
                    display_name = "Data Science"
                    description  = "NumPy, Pandas, Scikit-learn, Matplotlib"
                    default      = true
                    kubespawner_override = {
                      image = "quay.io/jupyter/datascience-notebook:python-3.11"
                    }
                  }
                  tensorflow = {
                    display_name = "TensorFlow"
                    description  = "Deep Learning com TensorFlow e Keras"
                    kubespawner_override = {
                      image = "quay.io/jupyter/tensorflow-notebook:latest"
                    }
                  }
                  pytorch = {
                    display_name = "PyTorch"
                    description  = "Deep Learning com PyTorch e Lightning"
                    kubespawner_override = {
                      image = "quay.io/jupyter/pytorch-notebook:latest"
                    }
                  }
                  pyspark = {
                    display_name = "PySpark"
                    description  = "Processamento distribuído com Apache Spark"
                    kubespawner_override = {
                      image = "quay.io/jupyter/all-spark-notebook:spark-3.5.0"
                    }
                  }
                }
              }
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

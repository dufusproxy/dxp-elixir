defmodule CoreWeb.OpenAPIController do
  @moduledoc """
  Controller for serving the OpenAPI schema.
  """
  use CoreWeb, :controller

  def index(conn, _params) do
    # Generate OpenAPI schema from AshJsonApi resources
    schema = generate_openapi_schema()

    json(conn, schema)
  end

  defp generate_openapi_schema do
    %{
      "openapi" => "3.0.0",
      "info" => %{
        "title" => "DXP Content API",
        "version" => "1.0.0",
        "description" => "API for the DXP content management system"
      },
      "servers" => [
        %{
          "url" => "/api/v1",
          "description" => "API v1"
        }
      ],
      "paths" => generate_paths(),
      "components" => %{
        "schemas" => generate_schemas()
      }
    }
  end

  defp generate_paths do
    %{
      "/assets" => %{
        "post" => %{
          "summary" => "Create an asset",
          "requestBody" => asset_request_body(),
          "responses" => %{
            "201" => %{
              "description" => "Asset created",
              "content" => %{
                "application/vnd.api+json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/Asset"}
                }
              }
            },
            "400" => %{"description" => "Bad request"},
            "403" => %{"description" => "Forbidden"},
            "422" => %{"description" => "Unprocessable entity"}
          }
        }
      },
      "/assets/{id}" => %{
        "get" => %{
          "summary" => "Get an asset",
          "parameters" => [
            %{
              "name" => "id",
              "in" => "path",
              "required" => true,
              "schema" => %{"type" => "string", "format" => "uuid"}
            }
          ],
          "responses" => %{
            "200" => %{
              "description" => "Asset found",
              "content" => %{
                "application/vnd.api+json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/Asset"}
                }
              }
            },
            "404" => %{"description" => "Asset not found"}
          }
        },
        "patch" => %{
          "summary" => "Update an asset",
          "parameters" => [
            %{
              "name" => "id",
              "in" => "path",
              "required" => true,
              "schema" => %{"type" => "string", "format" => "uuid"}
            }
          ],
          "requestBody" => asset_request_body(),
          "responses" => %{
            "200" => %{
              "description" => "Asset updated",
              "content" => %{
                "application/vnd.api+json" => %{
                  "schema" => %{"$ref" => "#/components/schemas/Asset"}
                }
              }
            },
            "400" => %{"description" => "Bad request"},
            "403" => %{"description" => "Forbidden"},
            "404" => %{"description" => "Asset not found"},
            "422" => %{"description" => "Unprocessable entity"}
          }
        },
        "delete" => %{
          "summary" => "Delete an asset",
          "parameters" => [
            %{
              "name" => "id",
              "in" => "path",
              "required" => true,
              "schema" => %{"type" => "string", "format" => "uuid"}
            }
          ],
          "responses" => %{
            "200" => %{"description" => "Asset deleted"},
            "404" => %{"description" => "Asset not found"}
          }
        }
      },
      "/asset_links" => %{
        "post" => %{
          "summary" => "Add a link to an asset",
          "requestBody" => link_request_body(),
          "responses" => %{
            "200" => %{"description" => "Link created"},
            "400" => %{"description" => "Bad request"},
            "403" => %{"description" => "Forbidden"},
            "422" => %{"description" => "Unprocessable entity"}
          }
        }
      },
      "/permissions" => %{
        "post" => %{
          "summary" => "Grant or revoke permissions",
          "requestBody" => permission_request_body(),
          "responses" => %{
            "200" => %{"description" => "Permissions updated"},
            "400" => %{"description" => "Bad request"},
            "403" => %{"description" => "Forbidden"}
          }
        }
      }
    }
  end

  defp generate_schemas do
    %{
      "Asset" => asset_schema(),
      "AssetLink" => asset_link_schema(),
      "Permission" => permission_schema(),
      "Errors" => errors_schema()
    }
  end

  defp asset_schema do
    %{
      "type" => "object",
      "properties" => %{
        "type" => %{"type" => "string", "enum" => ["asset"]},
        "id" => %{"type" => "string", "format" => "uuid"},
        "attributes" => %{
          "type" => "object",
          "properties" => %{
            "type" => %{"type" => "string"},
            "role" => %{"type" => "string"},
            "state" => %{"type" => "string"},
            "inserted_at" => %{"type" => "string", "format" => "date-time"},
            "updated_at" => %{"type" => "string", "format" => "date-time"}
          }
        },
        "relationships" => %{
          "type" => "object",
          "properties" => %{
            "parent_links" => %{"$ref" => "#/components/schemas/AssetLink"},
            "child_links" => %{"$ref" => "#/components/schemas/AssetLink"},
            "permissions" => %{"$ref" => "#/components/schemas/Permission"}
          }
        }
      }
    }
  end

  defp asset_link_schema do
    %{
      "type" => "object",
      "properties" => %{
        "type" => %{"type" => "string", "enum" => ["asset_link"]},
        "id" => %{"type" => "string", "format" => "uuid"},
        "attributes" => %{
          "type" => "object",
          "properties" => %{
            "parent_id" => %{"type" => "string", "format" => "uuid"},
            "child_id" => %{"type" => "string", "format" => "uuid"},
            "link_type" => %{"type" => "string", "enum" => ["primary", "secondary", "notice"]}
          }
        }
      }
    }
  end

  defp permission_schema do
    %{
      "type" => "object",
      "properties" => %{
        "type" => %{"type" => "string", "enum" => ["permission"]},
        "id" => %{"type" => "string", "format" => "uuid"},
        "attributes" => %{
          "type" => "object",
          "properties" => %{
            "asset_id" => %{"type" => "string", "format" => "uuid"},
            "principal_id" => %{"type" => "string", "format" => "uuid"},
            "principal_type" => %{"type" => "string", "enum" => ["user", "group", "service"]},
            "level" => %{"type" => "string", "enum" => ["read", "write", "admin"]}
          }
        }
      }
    }
  end

  defp errors_schema do
    %{
      "type" => "object",
      "properties" => %{
        "errors" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "title" => %{"type" => "string"},
              "detail" => %{"type" => "string"},
              "status" => %{"type" => "string"},
              "code" => %{"type" => "string"}
            }
          }
        }
      }
    }
  end

  defp asset_request_body do
    %{
      "required" => true,
      "content" => %{
        "application/vnd.api+json" => %{
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"$ref" => "#/components/schemas/Asset"}
            }
          }
        }
      }
    }
  end

  defp link_request_body do
    %{
      "required" => true,
      "content" => %{
        "application/vnd.api+json" => %{
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"$ref" => "#/components/schemas/AssetLink"}
            }
          }
        }
      }
    }
  end

  defp permission_request_body do
    %{
      "required" => true,
      "content" => %{
        "application/vnd.api+json" => %{
          "schema" => %{
            "type" => "object",
            "properties" => %{
              "data" => %{"$ref" => "#/components/schemas/Permission"}
            }
          }
        }
      }
    }
  end
end

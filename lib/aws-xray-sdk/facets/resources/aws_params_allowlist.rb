module XRay
  # AWS SDK parameters whitelisted will be recorded
  # as metadata on AWS subsegments
  module AwsParams
    @whitelist = {
      services: {
        DynamoDB: {
          operations: {
            batch_get_item: {
              request_descriptors: {
                request_items: {
                  map: true,
                  get_keys: true,
                  rename_to: :table_names
                }
              },
              response_parameters: %I[
                consumed_capacity
              ]
            },
            batch_write_item: {
              request_descriptors: {
                request_items: {
                  map: true,
                  get_keys: true,
                  rename_to: :table_names
                }
              },
              response_parameters: %I[
                consumed_capacity
                item_collection_metrics
              ]
            },
            create_table: {
              request_parameters: %I[
                global_secondary_indexes
                local_secondary_indexes
                provisioned_throughput
                table_name
              ]
            },
            delete_item: {
              request_parameters: %I[
                table_name
              ],
              response_parameters: %I[
                consumed_capacity
                item_collection_metrics
              ]
            },
            delete_table: {
              request_parameters: %I[
                table_name
              ]
            },
            describe_table: {
              request_parameters: %I[
                table_name
              ]
            },
            get_item: {
              request_parameters: %I[
                consistent_read
                projection_expression
                table_name
              ],
              response_parameters: %I[
                consumed_capacity
              ]
            },
            list_tables: {
              request_parameters: %I[
                exclusive_start_table_name
                limit
              ],
              response_descriptors: {
                table_names: {
                  list: true,
                  get_count: true,
                  rename_to: :table_count
                }
              }
            },
            put_item: {
              request_parameters: %I[
                table_name
              ],
              response_parameters: %I[
                consumed_capacity
                item_collection_metrics
              ]
            },
            query: {
              request_parameters: %I[
                attributes_to_get
                consistent_read
                index_name
                limit
                projection_expression
                scan_index_forward
                select
                table_name
              ],
              response_parameters: %I[
                consumed_capacity
              ]
            },
            scan: {
              request_parameters: %I[
                attributes_to_get
                consistent_read
                index_name
                limit
                projection_expression
                segment
                select
                table_name
                total_segments
              ],
              response_parameters: %I[
                consumed_capacity
                count
                scanned_count
              ]
            },
            update_item: {
              request_parameters: %I[
                table_name
              ],
              response_parameters: %I[
                consumed_capacity
                item_collection_metrics
              ]
            },
            update_table: {
              request_parameters: %I[
                attribute_definitions
                global_secondary_index_updates
                provisioned_throughput
                table_name
              ]
            }
          }
        },
        SQS: {
          operations: {
            add_permission: {
              request_parameters: %I[
                label
                queue_url
              ]
            },
            change_message_visibility: {
              request_parameters: %I[
                queue_url
                visibility_timeout
              ]
            },
            change_message_visibility_batch: {
              request_parameters: %I[
                queue_url
              ],
              response_parameters: %I[
                failed
              ]
            },
            create_queue: {
              request_parameters: %I[
                attributes
                queue_name
              ]
            },
            delete_message: {
              request_parameters: %I[
                queue_urls
              ]
            },
            delete_message_batch: {
              request_parameters: %I[
                queue_url
              ],
              response_parameters: %I[
                failed
              ]
            },
            delete_queue: {
              request_parameters: %I[
                queue_url
              ]
            },
            get_queue_attributes: {
              request_parameters: %I[
                queue_url
              ],
              response_parameters: %I[
                attributes
              ]
            },
            get_queue_url: {
              request_parameters: %I[
                queue_name
                queue_owner_aws_account_id
              ],
              response_parameters: %I[
                queue_url
              ]
            },
            list_dead_letter_source_queues: {
              request_parameters: %I[
                queue_url
              ],
              response_parameters: %I[
                queue_urls
              ]
            },
            list_queues: {
              request_parameters: %I[
                queue_name_prefix
              ],
              response_descriptors: {
                queue_urls: {
                  list: true,
                  get_count: true,
                  rename_to: :queue_count
                }
              }
            },
            purge_queue: {
              request_parameters: %I[
                queue_url
              ]
            },
            receive_message: {
              request_parameters: %I[
                attribute_names
                max_number_of_messages
                message_attribute_names
                queue_url
                visibility_timeout
                wait_time_seconds
              ],
              response_descriptors: {
                messages: {
                  list: true,
                  get_count: true,
                  rename_to: :message_count
                }
              }
            },
            remove_permission: {
              request_parameters: %I[
                queue_url
              ]
            },
            send_message: {
              request_parameters: %I[
                delay_seconds
                queue_url
              ],
              request_descriptors: {
                message_attributes: {
                  map: true,
                  get_keys: true,
                  rename_to: :message_attribute_names
                }
              },
              response_parameters: %I[
                message_id
              ]
            },
            send_message_batch: {
              request_parameters: %I[
                queue_url
              ],
              request_descriptors: {
                entries: {
                  list: true,
                  get_count: true,
                  rename_to: :message_count
                }
              },
              response_descriptors: {
                failed: {
                  list: true,
                  get_count: true,
                  rename_to: :failed_count
                },
                successful: {
                  list: true,
                  get_count: true,
                  rename_to: :successful_count
                }
              }
            },
            set_queue_attributes: {
              request_parameters: %I[
                queue_url
              ],
              request_descriptors: {
                attributes: {
                  map: true,
                  get_keys: true,
                  rename_to: :attribute_names
                }
              }
            }
          }
        },
        Lambda: {
          operations: {
            invoke: {
              request_parameters: %I[
                function_name
                invocation_type
                log_type
                qualifier
              ],
              response_parameters: %I[
                function_error
                status_code
              ]
            },
            invoke_async: {
              request_parameters: %I[
                function_name
              ],
              response_parameters: %I[
                status
              ]
            }
          }
        },
        SageMakerRuntime: {
          operations: {
            invoke_endpoint: {
              request_parameters: %I[
                endpoint_name
              ]
            }
          }
        },
        SNS: {
          operations: {
            publish: {
              request_parameters: %I[
                topic_arn
              ]
            }
          }
        }
      }
    }

    def self.whitelist
      @whitelist
    end
  end
end

export interface Environment {
  id: number
  name: string
  base_url: string
  description?: string
  headers?: Record<string, any>
  created_at: string
  updated_at: string
}

export interface API {
  id: number
  path: string
  method: string
  summary?: string
  operation_id?: string
  tags?: string[]
  parameters?: any[]
  request_body?: any
  responses?: any
  swagger_file?: string
  created_at: string
  updated_at: string
  is_favorite?: boolean
}

export interface TestData {
  id: number
  api_id: number
  name: string
  path_params?: Record<string, any>
  query_params?: Record<string, any>
  headers?: Record<string, any>
  body?: Record<string, any>
  expected_status?: number
  expected_response?: Record<string, any>
  created_at: string
  updated_at: string
}

export interface ExecutionRecord {
  id: number
  api_id: number
  test_data_id?: number
  environment_id: number
  request_url?: string
  request_method?: string
  request_headers?: Record<string, any>
  request_body?: any
  response_status?: number
  response_headers?: Record<string, any>
  response_body?: any
  response_time?: number
  success?: boolean
  error_message?: string
  executed_at: string
}

export interface ExecuteRequest {
  environment_id: number
  test_data_id?: number
  path_params?: Record<string, any>
  query_params?: Record<string, any>
  headers?: Record<string, any>
  body?: Record<string, any>
}

export interface BatchExecuteRequest {
  environment_id: number
  api_ids?: number[]
}

export interface BatchExecuteResult {
  message: string
  total: number
  success: number
  failed: number
  results: Array<{
    api_id: number
    api_path: string
    api_method: string
    test_data_name?: string
    success: boolean
    response_status?: number
    response_time?: number
    error_message?: string
  }>
}


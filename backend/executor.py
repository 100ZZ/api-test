import requests
import time
import re
from typing import Dict, Any, Optional
from models import API, Environment, TestData
from sqlalchemy.orm import Session
import json
from jsonpath_ng import parse as jsonpath_parse

class APIExecutor:
    """API执行引擎"""
    
    def __init__(self, api: API, environment: Environment, db: Optional[Session] = None):
        self.api = api
        self.environment = environment
        self.db = db
        self.variables = {}  # 存储提取的变量
        
    def execute(self, 
                path_params: Optional[Dict[str, Any]] = None,
                query_params: Optional[Dict[str, Any]] = None,
                headers: Optional[Dict[str, Any]] = None,
                body: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """执行API请求"""
        
        # 构建URL
        url = self._build_url(path_params)
        
        # 合并请求头
        request_headers = self._merge_headers(headers)
        
        # 准备请求参数
        request_kwargs = {
            'method': self.api.method,
            'url': url,
            'headers': request_headers,
        }
        
        # 添加查询参数
        if query_params:
            request_kwargs['params'] = query_params
        
        # 添加请求体
        if body and self.api.method.upper() in ['POST', 'PUT', 'PATCH']:
            content_type = request_headers.get('Content-Type', 'application/json')
            if 'application/json' in content_type:
                request_kwargs['json'] = body
            else:
                request_kwargs['data'] = body
        
        # 执行请求
        start_time = time.time()
        try:
            response = requests.request(**request_kwargs, timeout=30)
            response_time = int((time.time() - start_time) * 1000)  # 毫秒
            
            # 解析响应体
            try:
                response_body = response.json()
            except:
                response_body = response.text
            
            # 构建响应头字典
            response_headers = dict(response.headers)
            
            return {
                'request_url': url,
                'request_method': self.api.method,
                'request_headers': request_headers,
                'request_body': body,
                'response_status': response.status_code,
                'response_headers': response_headers,
                'response_body': response_body,
                'response_time': response_time,
                'success': 200 <= response.status_code < 300,
                'error_message': None
            }
        except Exception as e:
            response_time = int((time.time() - start_time) * 1000)
            return {
                'request_url': url,
                'request_method': self.api.method,
                'request_headers': request_headers,
                'request_body': body,
                'response_status': None,
                'response_headers': None,
                'response_body': None,
                'response_time': response_time,
                'success': False,
                'error_message': str(e)
            }
    
    def execute_with_test_data(self, test_data: TestData) -> Dict[str, Any]:
        """使用测试数据执行API（支持前置接口）"""
        # 1. 执行前置接口（如果配置了）
        if test_data.pre_request_api_id and self.db:
            self._execute_pre_request(test_data)
        
        # 2. 替换参数中的变量占位符
        path_params = self._replace_variables(test_data.path_params)
        query_params = self._replace_variables(test_data.query_params)
        headers = self._replace_variables(test_data.headers)
        body = self._replace_variables(test_data.body)
        
        # 3. 执行主接口
        return self.execute(
            path_params=path_params,
            query_params=query_params,
            headers=headers,
            body=body
        )
    
    def _build_url(self, path_params: Optional[Dict[str, Any]] = None) -> str:
        """构建完整的URL"""
        url = self.environment.base_url + self.api.path
        
        # 替换路径参数
        if path_params:
            for key, value in path_params.items():
                url = url.replace(f'{{{key}}}', str(value))
        
        return url
    
    def _merge_headers(self, headers: Optional[Dict[str, Any]] = None) -> Dict[str, str]:
        """合并请求头（环境请求头 + 自定义请求头）"""
        merged_headers = {}
        
        # 添加环境请求头
        if self.environment.headers:
            for key, value in self.environment.headers.items():
                merged_headers[key] = str(value)
        
        # 添加自定义请求头
        if headers:
            for key, value in headers.items():
                merged_headers[key] = str(value)
        
        return merged_headers
    
    def _execute_pre_request(self, test_data: TestData) -> None:
        """执行前置接口并提取变量"""
        try:
            # 获取前置接口配置
            pre_api = self.db.query(API).filter(API.id == test_data.pre_request_api_id).first()
            if not pre_api:
                print(f"⚠️ 警告: 找不到前置接口 ID={test_data.pre_request_api_id}")
                return
            
            # 获取前置接口的测试数据（如果指定）
            pre_test_data = None
            if test_data.pre_request_test_data_id:
                pre_test_data = self.db.query(TestData).filter(
                    TestData.id == test_data.pre_request_test_data_id
                ).first()
            
            # 创建前置接口的执行器
            pre_executor = APIExecutor(pre_api, self.environment, self.db)
            
            # 执行前置接口
            if pre_test_data:
                print(f"🔄 执行前置接口: {pre_api.method} {pre_api.path} (使用测试数据: {pre_test_data.name})")
                result = pre_executor.execute(
                    path_params=pre_test_data.path_params,
                    query_params=pre_test_data.query_params,
                    headers=pre_test_data.headers,
                    body=pre_test_data.body
                )
            else:
                print(f"🔄 执行前置接口: {pre_api.method} {pre_api.path} (无测试数据)")
                result = pre_executor.execute()
            
            # 检查前置接口是否执行成功
            if not result.get('success'):
                error_msg = result.get('error_message', '未知错误')
                print(f"❌ 前置接口执行失败: {error_msg}")
                return
            
            # 提取变量
            response_body = result.get('response_body')
            if response_body and test_data.variable_extractions:
                self._extract_variables(response_body, test_data.variable_extractions)
                print(f"✅ 前置接口执行成功，提取变量: {list(self.variables.keys())}")
            
        except Exception as e:
            print(f"❌ 执行前置接口时发生错误: {str(e)}")
    
    def _extract_variables(self, response_body: Any, extraction_rules: Dict[str, str]) -> None:
        """从响应中提取变量
        
        Args:
            response_body: 响应体（通常是字典）
            extraction_rules: 提取规则，格式: {"varName": "$.data.accessToken"}
        """
        if not isinstance(response_body, dict):
            print(f"⚠️ 警告: 响应体不是字典类型，无法提取变量")
            return
        
        for var_name, jsonpath_expr in extraction_rules.items():
            try:
                # 使用 JSONPath 提取值
                if jsonpath_expr.startswith('$.'):
                    # 使用 jsonpath_ng 库
                    jsonpath_expression = jsonpath_parse(jsonpath_expr)
                    matches = jsonpath_expression.find(response_body)
                    if matches:
                        value = matches[0].value
                        self.variables[var_name] = value
                        print(f"  📌 提取变量 {var_name} = {value}")
                    else:
                        print(f"  ⚠️ 未找到匹配的值: {jsonpath_expr}")
                else:
                    # 简单的字典键访问，支持点号分隔的路径
                    keys = jsonpath_expr.split('.')
                    value = response_body
                    for key in keys:
                        if isinstance(value, dict) and key in value:
                            value = value[key]
                        else:
                            print(f"  ⚠️ 路径不存在: {jsonpath_expr}")
                            value = None
                            break
                    if value is not None:
                        self.variables[var_name] = value
                        print(f"  📌 提取变量 {var_name} = {value}")
            except Exception as e:
                print(f"  ❌ 提取变量 {var_name} 时出错: {str(e)}")
    
    def _replace_variables(self, data: Any) -> Any:
        """递归替换数据中的变量占位符
        
        支持的占位符格式: {{variableName}}
        """
        if data is None:
            return data
        
        if isinstance(data, str):
            # 替换字符串中的变量占位符
            for var_name, var_value in self.variables.items():
                placeholder = f"{{{{{var_name}}}}}"
                if placeholder in data:
                    # 如果整个字符串就是占位符，直接返回变量值（保持类型）
                    if data == placeholder:
                        return var_value
                    # 否则进行字符串替换
                    data = data.replace(placeholder, str(var_value))
            return data
        
        elif isinstance(data, dict):
            # 递归处理字典
            return {key: self._replace_variables(value) for key, value in data.items()}
        
        elif isinstance(data, list):
            # 递归处理列表
            return [self._replace_variables(item) for item in data]
        
        else:
            # 其他类型直接返回
            return data


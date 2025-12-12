<template>
  <div class="api-test-container">
    <!-- 头部 -->
      <el-header class="header">
        <h1>接口测试平台</h1>
        <div class="header-actions">
          <el-button type="info" @click="handleOpenGlobalPreRequest" :icon="Setting">
            前置操作
          </el-button>
          <el-button type="warning" @click="handleSyncFromUrl" :icon="Refresh" :loading="syncing">
            同步接口
          </el-button>
        <el-button type="primary" @click="showSwaggerDialog = true" :icon="Upload">
          上传Swagger文件
        </el-button>
        <el-button type="success" @click="showMarkdownDialog = true" :icon="Upload">
          上传Markdown文档
        </el-button>
        <el-button type="danger" @click="handleDeleteAll" :icon="Delete">
          清空所有接口
        </el-button>
      </div>
    </el-header>

    <!-- 主内容区 -->
    <el-container class="main-container">
      <!-- 左侧接口列表 -->
      <el-aside width="400px" class="aside">
        <div class="aside-header">
          <h3>接口列表 ({{ apis.length }})</h3>
        </div>
        
        <div class="filter-box">
          <el-select 
            v-model="filterMethod" 
            placeholder="请选择方法" 
            clearable 
            size="small"
            style="margin-bottom: 10px;">
            <el-option label="GET" value="GET" />
            <el-option label="POST" value="POST" />
            <el-option label="PUT" value="PUT" />
            <el-option label="DELETE" value="DELETE" />
            <el-option label="PATCH" value="PATCH" />
          </el-select>
          
          <el-input
            v-model="searchKeyword"
            placeholder="搜索接口路径、描述..."
            clearable
            size="small"
            :prefix-icon="Search">
          </el-input>
        </div>

        <div class="api-list">
          <el-scrollbar height="calc(100vh - 240px)">
            <div 
              v-for="api in filteredApis" 
              :key="api.id" 
              class="api-item"
              :class="{ active: selectedApi?.id === api.id }"
              @click="selectApi(api)">
              <div class="api-item-header">
                <el-tag :type="getMethodType(api.method)" size="small">
                  {{ api.method }}
                </el-tag>
                <span class="api-path">{{ api.path }}</span>
                <div class="api-item-actions">
                  <el-button 
                    :type="api.is_favorite ? 'warning' : 'info'"
                    size="small" 
                    :icon="Star"
                    circle
                    text
                    @click.stop="toggleFavorite(api)"
                    :class="['favorite-btn', { 'is-favorite': api.is_favorite }]"
                    :title="api.is_favorite ? '取消收藏' : '收藏'" />
                  <el-button 
                    v-if="testMode === 'chain'"
                    type="primary" 
                    size="small" 
                    :icon="Plus"
                    circle
                    @click.stop="addToChain(api)"
                    class="add-to-chain-btn" 
                    title="添加到执行链" />
                </div>
              </div>
              <div class="api-item-summary" v-if="api.summary">
                {{ api.summary }}
              </div>
              <div class="api-item-tags" v-if="api.tags && api.tags.length">
                <el-tag v-for="tag in api.tags" :key="tag" size="small" type="info">
                  {{ tag }}
                </el-tag>
              </div>
            </div>
            <el-empty v-if="filteredApis.length === 0" :description="apis.length === 0 ? '暂无接口数据' : '未找到匹配的接口'" />
          </el-scrollbar>
        </div>
      </el-aside>

      <!-- 中间：接口详情区域 -->
      <el-main class="main-center">
        <!-- 单接口测试模式 -->
        <div v-if="testMode === 'single' && selectedApi" class="api-detail">
          <!-- 环境选择 -->
          <el-card class="detail-card">
            <template #header>
              <div class="card-header">
                <span>环境配置</span>
                <el-button 
                  type="primary" 
                  size="small" 
                  @click="handleAddEnvironment"
                  :icon="Plus">
                  添加环境
                </el-button>
              </div>
            </template>
            <el-select 
              v-model="selectedEnvironment" 
              placeholder="请选择环境" 
              style="width: 100%"
              popper-class="env-select-dropdown">
                  <el-option 
                    v-for="(env, index) in environments" 
                    :key="env.id" 
                :label="getFullEnvLabel(env)" 
                :value="env.id"
                style="height: auto; padding: 10px;">
                <div style="display: flex; align-items: center; justify-content: space-between;">
                  <div style="flex: 1; min-width: 0; padding-right: 10px; word-break: break-all;">
                    {{ env.name }} - {{ env.base_url }}
                  </div>
                  <div style="display: flex; gap: 4px; flex-shrink: 0;">
                    <el-button 
                      size="small" 
                      text 
                      type="info"
                      @click.stop="moveEnvironment(index, -1)"
                      :disabled="index === 0"
                      :icon="ArrowUp"
                      title="上移">
                    </el-button>
                    <el-button 
                      size="small" 
                      text 
                      type="info"
                      @click.stop="moveEnvironment(index, 1)"
                      :disabled="index === environments.length - 1"
                      :icon="ArrowDown"
                      title="下移">
                    </el-button>
                    <el-button 
                      size="small" 
                      text 
                      type="primary"
                      @click.stop="handleEditEnvironment(env)"
                      :icon="Edit"
                      title="编辑">
                    </el-button>
                    <el-button 
                      size="small" 
                      text 
                      type="danger"
                      @click.stop="handleDeleteEnvironment(env.id)"
                      :icon="Delete"
                      title="删除">
                    </el-button>
                  </div>
                </div>
                  </el-option>
                </el-select>
          </el-card>

          <!-- 接口信息 -->
          <el-card class="detail-card">
            <template #header>
              <div class="card-header">
                <span>接口详情</span>
                <el-button 
                  type="primary" 
                  size="small" 
                  @click="handleExecute"
                  :loading="executing"
                  :icon="VideoPlay">
                  执行接口
                </el-button>
              </div>
            </template>

            <el-descriptions :column="2" border>
              <el-descriptions-item label="路径">{{ selectedApi.path }}</el-descriptions-item>
              <el-descriptions-item label="方法">
                <el-tag :type="getMethodType(selectedApi.method)">
                  {{ selectedApi.method }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="描述" :span="2">
                {{ selectedApi.summary || '-' }}
              </el-descriptions-item>
            </el-descriptions>
          </el-card>

          <!-- 请求参数（合并测试数据） -->
          <el-card class="detail-card request-params-card">
            <template #header>
              <div class="card-header">
                <div class="header-left">
                  <span>请求参数</span>
                </div>
              </div>
            </template>
            
            <div class="params-container">
              <!-- 左侧：参数输入区域 -->
              <div class="params-input-area">
                <el-tabs v-model="activeTab">
              <el-tab-pane label="Header" name="headers">
                <el-input 
                  v-model="headersText" 
                  type="textarea" 
                  :rows="20"
                  :placeholder="headersPlaceholder" />
              </el-tab-pane>
              
              <el-tab-pane label="Query" name="query">
                <el-input 
                  v-model="queryParamsText" 
                  type="textarea" 
                  :rows="20"
                  :placeholder="queryPlaceholder" />
              </el-tab-pane>
              
              <el-tab-pane label="Form Data" name="formData" v-if="hasFormData">
                <div class="form-data-container">
                  <el-table :data="formDataFields" border style="width: 100%">
                    <el-table-column label="KEY" width="200">
                      <template #default="{ row }">
                        <el-input v-model="row.key" placeholder="参数名" size="small" />
                      </template>
                    </el-table-column>
                    
                    <el-table-column label="VALUE" min-width="300">
                      <template #default="{ row }">
                        <!-- 文件类型 -->
                        <div v-if="row.type === 'file'" class="file-upload-cell">
                          <el-upload
                            ref="uploadRef"
                            :auto-upload="false"
                            :limit="1"
                            :on-change="(file: any) => handleFormFileChange(row, file)"
                            :on-remove="() => handleFormFileRemove(row)"
                            :file-list="row.fileList"
                            class="form-file-upload">
                            <el-button size="small" :icon="Upload">选择文件</el-button>
                          </el-upload>
                          <el-text v-if="row.fileName" type="success" size="small" style="margin-left: 10px">
                            {{ row.fileName }}
                          </el-text>
                        </div>
                        
                        <!-- 普通文本类型 -->
                <el-input 
                          v-else
                          v-model="row.value" 
                          placeholder="参数值" 
                          size="small" />
                      </template>
                    </el-table-column>
                    
                    <el-table-column label="类型" width="120">
                      <template #default="{ row }">
                        <el-select v-model="row.type" size="small" @change="handleFormTypeChange(row)">
                          <el-option label="Text" value="text" />
                          <el-option label="File" value="file" />
                        </el-select>
                      </template>
                    </el-table-column>
                    
                    <el-table-column label="描述" width="200">
                      <template #default="{ row }">
                        <el-text size="small" type="info">{{ row.description }}</el-text>
                      </template>
                    </el-table-column>
                    
                    <el-table-column label="操作" width="80" fixed="right">
                      <template #default="{ $index }">
                        <el-button 
                          size="small" 
                          type="danger" 
                          :icon="Delete"
                          link
                          @click="removeFormDataField($index)" />
                      </template>
                    </el-table-column>
                  </el-table>
                  
                  <el-button 
                    type="primary" 
                    size="small" 
                    :icon="Plus"
                    style="margin-top: 10px"
                    @click="addFormDataField">
                    添加字段
                  </el-button>
                </div>
              </el-tab-pane>
              
              <el-tab-pane label="Body" name="body" v-if="['POST', 'PUT', 'PATCH'].includes(selectedApi.method) && !hasFormData">
                <el-input 
                  v-model="bodyText" 
                  type="textarea" 
                  :rows="20"
                  :placeholder="bodyPlaceholder" />
              </el-tab-pane>
              
              <el-tab-pane label="Path" name="path">
                <el-input 
                  v-model="pathParamsText" 
                  type="textarea" 
                  :rows="20"
                  :placeholder="pathPlaceholder" />
              </el-tab-pane>
              
              <el-tab-pane label="Assertion" name="assertions">
                <div class="api-assertions-section">
                  <div class="assertions-list">
                    <div 
                      v-for="(assertion, index) in assertions" 
                      :key="index" 
                      class="assertion-item">
                      <div class="assertion-row">
                        <!-- Type/Status 字段 -->
                        <div class="assertion-field">
                          <el-select 
                            v-model="assertion.type" 
                            placeholder="选择类型" 
                            size="default"
                            style="width: 140px;">
                            <el-option label="状态码" value="status_code">
                              <span style="display: flex; align-items: center; gap: 8px;">
                                <el-icon><Check /></el-icon>
                                <span>状态码</span>
                              </span>
                            </el-option>
                            <el-option label="JSON路径" value="json_path">
                              <span style="display: flex; align-items: center; gap: 8px;">
                                <el-icon><Document /></el-icon>
                                <span>JSON路径</span>
                              </span>
                            </el-option>
                            <el-option label="响应时间" value="response_time">
                              <span style="display: flex; align-items: center; gap: 8px;">
                                <el-icon><DataAnalysis /></el-icon>
                                <span>响应时间</span>
                              </span>
                            </el-option>
                            <el-option label="包含" value="contains">
                              <span style="display: flex; align-items: center; gap: 8px;">
                                <el-icon><Search /></el-icon>
                                <span>包含</span>
                              </span>
                            </el-option>
                          </el-select>
                        </div>
                        
                        <!-- JSON Path 输入框（当类型为 json_path 时显示） -->
                        <div class="assertion-field" v-if="assertion.type === 'json_path'">
                          <el-input 
                            v-model="assertion.path" 
                            placeholder="例如: data.id"
                            clearable
                            size="default"
                            style="width: 200px;">
                            <template #prepend>$.</template>
                          </el-input>
                        </div>
                        
                        <!-- Operator 操作符 -->
                        <div class="assertion-field">
                          <el-select 
                            v-model="assertion.operator" 
                            placeholder="选择操作符" 
                            size="default"
                            style="width: 120px;">
                            <el-option label="等于" value="eq" />
                            <el-option label="不等于" value="ne" />
                            <el-option label="大于" value="gt" />
                            <el-option label="小于" value="lt" />
                            <el-option label="包含" value="contains" />
                            <el-option label="不包含" value="not_contains" />
                          </el-select>
                        </div>
                        
                        <!-- Expected 期望值 -->
                        <div class="assertion-field">
                          <el-input 
                            v-model="assertion.expected" 
                            :placeholder="getExpectedPlaceholder(assertion.type)"
                            clearable
                            size="default"
                            style="width: 150px;" />
                        </div>
                        
                        <!-- 操作按钮 -->
                        <div class="assertion-actions-inline">
                          <el-button 
                            type="primary" 
                            size="small" 
                            :icon="Plus"
                            @click="insertAssertion(index + 1)"
                            circle 
                            title="在此行后新增断言" />
                          <el-button 
                            type="danger" 
                            size="small" 
                            :icon="Delete"
                            @click="removeAssertion(index)"
                            circle 
                            title="删除此断言" />
                        </div>
                      </div>
                      
                      <!-- Assertion result display -->
                      <div v-if="assertion.result !== undefined" class="assertion-result">
                        <el-tag :type="assertion.result ? 'success' : 'danger'" size="large">
                          <span style="font-weight: 600;">
                            {{ assertion.result ? '✓ 通过' : '✗ 失败' }}
                          </span>
                        </el-tag>
                        <span v-if="!assertion.result" class="assertion-error">
                          实际值: {{ assertion.actualValue }}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </el-tab-pane>
                </el-tabs>
              </div>
              
              <!-- 右侧：测试数据列表 -->
              <div class="test-data-panel">
                <div class="test-data-actions">
                  <el-button 
                    type="success" 
                    @click="handleGenerateTestData"
                    :icon="MagicStick"
                    class="test-data-action-btn">
                    生成数据
                  </el-button>
                  <el-button 
                    v-if="selectedTestData"
                    type="warning" 
                    @click="handleUpdateTestData"
                    :icon="Edit"
                    class="test-data-action-btn">
                    保存修改
                  </el-button>
              <el-button 
                type="info" 
                @click="handleExportApiData"
                :icon="Document"
                class="test-data-action-btn">
                导出数据
              </el-button>
                </div>
                
                <el-divider style="margin: 12px 0;" />
                
                <div class="test-data-list">
                  <div class="list-title">测试数据</div>
                  <el-scrollbar height="300px">
                    <div v-if="testDataList.length === 0" class="empty-list">
                      <el-empty description="暂无测试数据" :image-size="60" />
                    </div>
                    <div v-else class="test-data-items">
                      <div 
                        v-for="td in testDataList" 
                        :key="td.id"
                        class="test-data-item"
                        :class="{ active: selectedTestData === td.id }"
                        @click="selectTestDataItem(td.id)">
                        <div class="item-content">
                          <el-icon class="item-icon"><Document /></el-icon>
                          <span class="item-name">{{ td.name }}</span>
                        </div>
                        <el-button 
                          type="danger" 
                          size="small" 
                          text 
                          circle
                          @click.stop="handleDeleteTestData(td.id)"
                          :icon="Delete"
                          class="delete-icon">
                        </el-button>
                      </div>
                    </div>
                  </el-scrollbar>
                </div>
              </div>
            </div>
          </el-card>

          <!-- 执行结果 -->
          <el-card class="detail-card" v-if="executionResult">
            <template #header>
              <div class="card-header">
                <span>执行结果</span>
                <div class="result-tags">
                  <el-tag :type="executionResult.success ? 'success' : 'danger'">
                    {{ executionResult.success ? '成功' : '失败' }}
                  </el-tag>
                  <el-tag v-if="assertionSummary.total > 0" :type="assertionSummary.failed === 0 ? 'success' : 'danger'">
                    Assertion: {{ assertionSummary.passed }}/{{ assertionSummary.total }}
                  </el-tag>
                </div>
              </div>
            </template>

            <el-descriptions :column="2" border>
              <el-descriptions-item label="状态码">
                <el-tag :type="getStatusType(executionResult.response_status)">
                  {{ executionResult.response_status || '-' }}
                </el-tag>
              </el-descriptions-item>
              <el-descriptions-item label="响应时间">
                {{ executionResult.response_time }}ms
              </el-descriptions-item>
              <el-descriptions-item label="请求URL" :span="2">
                {{ executionResult.request_url }}
              </el-descriptions-item>
            </el-descriptions>

            <div class="result-section">
              <h4>响应体</h4>
              <el-input 
                v-model="responseBodyText" 
                type="textarea" 
                :rows="12"
                readonly />
            </div>

            <div class="result-section" v-if="executionResult.error_message">
              <h4>错误信息</h4>
              <el-alert :title="executionResult.error_message" type="error" :closable="false" />
            </div>
          </el-card>
        </div>

        <!-- 串联执行模式 -->
        <div v-if="testMode === 'chain'" class="chain-mode">
          <div class="chain-container">
            <!-- 左侧：执行链 -->
            <div class="chain-left-panel">
              <el-card class="chain-card">
                <template #header>
                  <div class="card-header">
                    <span><el-icon><Connection /></el-icon> 执行链 ({{ chainApis.length }})</span>
                    <div>
                      <el-button 
                        type="primary" 
                        size="small" 
                        @click="executeChain" 
                        :loading="chainExecuting"
                        :disabled="chainApis.length === 0 || !chainEnvironment"
                        :icon="VideoPlay">
                        执行
                      </el-button>
                      <el-button 
                        type="success" 
                        size="small" 
                        :icon="FolderAdd"
                        @click="handleSaveChain">
                        保存
                      </el-button>
                      <el-button 
                        type="danger" 
                        size="small" 
                        :icon="Delete"
                        @click="clearChain">
                        清空
                      </el-button>
                      <el-button 
                        type="primary"
                        size="small" 
                        :icon="Upload"
                        @click="handleImportPlan">
                        导入
                      </el-button>
                    </div>
                  </div>
                </template>

                <el-empty 
                  v-if="chainApis.length === 0" 
                  description="从左侧接口列表点击添加"
                  :image-size="80" />

                <el-scrollbar v-else height="calc(100vh - 260px)">
                  <div 
                    v-for="(item, index) in chainApis" 
                    :key="item.id + '-' + index"
                    class="chain-item"
                    :class="{ 'executing': chainExecuting && index === currentExecutingIndex, active: activeChainIndex === index }"
                    @click="selectChainItem(index)">
                    <div class="chain-item-header">
                      <span class="chain-order">{{ index + 1 }}</span>
                      <el-tag :type="getMethodType(item.method)" size="small">{{ item.method }}</el-tag>
                      <span class="chain-path">{{ item.path }}</span>
                      <div class="chain-actions">
                        <el-button 
                          :icon="Top" 
                          size="small" 
                          circle
                          @click.stop="moveChainItem(index, -1)"
                          :disabled="index === 0" />
                        <el-button 
                          :icon="Bottom" 
                          size="small" 
                          circle
                          @click.stop="moveChainItem(index, 1)"
                          :disabled="index === chainApis.length - 1" />
                        <el-button 
                          :icon="Document" 
                          size="small" 
                          circle
                          @click.stop="duplicateChainItem(index)"
                          title="复制并新增同款接口" />
                        <el-button 
                          :icon="Close" 
                          size="small" 
                          circle
                          type="danger"
                          @click.stop="removeFromChain(index)" />
                      </div>
                    </div>
                    <div class="chain-summary">{{ item.summary }}</div>
                    <div class="chain-quick-status">
                      <template v-if="chainResults[index]">
                            <el-tag :type="chainResults[index].success ? 'success' : 'danger'" size="small">
                              {{ chainResults[index].success ? '成功' : '失败' }}
                            </el-tag>
                        <span class="status-chip">状态码: {{ chainResults[index].response?.response_status || '-' }}</span>
                        <span class="status-chip">耗时: {{ chainResults[index].response?.response_time || 0 }}ms</span>
                            <el-tag 
                              v-if="(chainResults[index] as any).assertionSummary && (chainResults[index] as any).assertionSummary.total > 0" 
                              :type="(chainResults[index] as any).assertionSummary.failed === 0 ? 'success' : 'danger'"
                              size="small">
                              Assertion: {{ (chainResults[index] as any).assertionSummary.passed }}/{{ (chainResults[index] as any).assertionSummary.total }}"
                            </el-tag>
                            <el-button 
                              size="small" 
                              link 
                          type="primary"
                          @click.stop="openResultDrawer(index)">
                              查看详情
                            </el-button>
                      </template>
                      <template v-else>
                        <span class="chain-status-hint">尚未执行，点击右上角开始</span>
                      </template>
                    </div>
                  </div>
                </el-scrollbar>
              </el-card>
            </div>

            <!-- 右侧：配置和统计 -->
            <div class="chain-right-panel">
              <el-card class="chain-card">
                <template #header>
                  <div class="card-header">
                    <span><el-icon><Setting /></el-icon> 执行配置</span>
                  </div>
                </template>

                <el-form label-width="80px" size="default">
                  <el-form-item label="执行环境">
                    <el-select v-model="chainEnvironment" placeholder="选择环境" style="width: 100%">
                      <el-option 
                        v-for="env in environments" 
                        :key="env.id" 
                        :label="env.name" 
                        :value="env.id" />
                    </el-select>
                  </el-form-item>
                  
                  <el-form-item label="执行失败">
                    <el-radio-group v-model="chainStopOnError">
                      <el-radio :label="true">停止执行</el-radio>
                      <el-radio :label="false">继续执行</el-radio>
                    </el-radio-group>
                  </el-form-item>
                  
                  <el-form-item label="延迟(ms)">
                    <el-input-number 
                      v-model="chainDelay" 
                      :min="0" 
                      :max="10000" 
                      :step="100"
                      style="width: 100%" />
                  </el-form-item>

                  <el-form-item label="生成变量">
                    <div class="generate-var-actions">
                      <el-button
                        type="primary"
                        size="small"
                        plain
                        @click="generateTimestamp">
                        时间戳
                      </el-button>
                      <el-button
                        type="success"
                        size="small"
                        plain
                        @click="generateDateString">
                        时间点
                      </el-button>
                    </div>
                  </el-form-item>

                  <el-form-item>
                    <template #label>
                      <div style="display: flex; flex-direction: column; gap: 4px;">
                        <span>全局变量</span>
                        <el-tooltip effect="dark" placement="top" width="400">
                          <template #content>
                            <div style="white-space: pre-line; font-size: 12px; line-height: 1.8;">
                              使用 <code v-pre>$.global.变量名</code> 在 Header/Query/Body 中引用；变量值可为字符串或 JSON。
                            </div>
                          </template>
                          <el-icon style="cursor: help; color: #909399; align-self: flex-start;" :size="14">
                            <QuestionFilled />
                          </el-icon>
                        </el-tooltip>
                      </div>
                    </template>
                    <div class="global-var-list">
                      <div 
                        v-for="(item, idx) in chainGlobalVars" 
                        :key="idx" 
                        class="global-var-row">
                        <el-input 
                          v-model="item.key" 
                          placeholder="变量名，如 accessToken" 
                          size="small" />
                        <el-input 
                          v-model="item.value" 
                          placeholder='变量值，支持字符串或JSON，如 {"token":"xxx"}' 
                          size="small" />
                        <div style="display: flex; gap: 2px;">
                          <el-button 
                            :icon="Delete" 
                            type="danger" 
                            circle 
                            size="small"
                            @click="removeGlobalVar(idx)" />
                          <el-button 
                            :icon="DocumentCopy" 
                            type="primary" 
                            circle 
                            size="small"
                            @click="copyGlobalVarReference(item.key)" />
                        </div>
                      </div>
                    <div class="global-var-actions">
                      <el-button 
                        type="primary" 
                        size="small" 
                        :icon="Plus"
                        plain
                        @click="addGlobalVar">
                        新增变量
                      </el-button>
                      <el-button 
                        type="success" 
                        size="small" 
                        plain
                        @click="saveChainGlobalVars">
                        保存变量
                      </el-button>
                    </div>
                    </div>
                  </el-form-item>
                </el-form>

                <el-divider />

                <div class="chain-statistics">
                  <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
                    <h4 style="margin: 0; color: #303133;">
                      <el-icon><DataAnalysis /></el-icon> 执行统计
                    </h4>
                    <el-button
                      type="primary"
                      size="small"
                      :icon="Document"
                      :disabled="chainResults.length === 0"
                      @click="showExecutionDetailDrawer = true">
                      执行详情
                    </el-button>
                  </div>
                  <div class="stat-row">
                    <div class="stat-item">
                      <div class="stat-label">总数</div>
                      <div class="stat-value">{{ chainApis.length }}</div>
                    </div>
                    <div class="stat-item success">
                      <div class="stat-label">成功</div>
                      <div class="stat-value">{{ chainSuccessCount }}</div>
                    </div>
                    <div class="stat-item error">
                      <div class="stat-label">失败</div>
                      <div class="stat-value">{{ chainFailCount }}</div>
                    </div>
                  </div>
                  <div class="progress-section">
                    <div class="progress-label">执行进度</div>
                    <el-progress 
                      :percentage="chainProgress" 
                      :status="chainExecuting ? undefined : (chainFailCount > 0 ? 'exception' : 'success')"
                      :stroke-width="12" />
                  </div>
                </div>
              </el-card>
            </div>
          </div>
        </div>
      </el-main>

      <!-- 右侧：流程列表 -->
      <el-aside width="320px" class="chain-plans-aside">
        <div class="chain-plans-container">
          <div class="chain-plans-header">
            <h3>流程列表 ({{ filteredChainPlans.length }})</h3>
                    <el-button 
                      type="success"
                      size="small" 
                      :icon="List"
                      @click="handleCreateNewPlan">
                      新增
                    </el-button>
          </div>
          
          <!-- 搜索框 -->
          <div class="chain-search-box">
            <el-input
              v-model="chainSearchKeyword"
              placeholder="搜索方案名称、描述..."
              clearable
              size="small"
              :prefix-icon="Search">
            </el-input>
          </div>

          <el-scrollbar height="calc(100vh - 260px)">
            <div v-if="filteredChainPlans.length === 0" class="empty-plans">
              <el-empty :description="chainPlans.length === 0 ? '暂无保存的方案' : '未找到匹配的方案'" :image-size="80" />
            </div>
            <div v-else class="plan-list">
              <div 
                v-for="plan in filteredChainPlans" 
                :key="plan.id"
                class="plan-item"
                :class="{ active: currentPlanId === plan.id }"
                @click="loadPlanToChain(plan)">
                <div class="plan-header">
                  <el-icon class="plan-icon"><Connection /></el-icon>
                  <span class="plan-name">{{ plan.name }}</span>
                  <div class="plan-actions" @click.stop>
                    <el-button 
                      type="info" 
                      size="small" 
                      link
                      :icon="Edit"
                      @click="editPlan(plan)"
                      title="编辑" />
                    <el-button 
                      type="primary" 
                      size="small" 
                      link
                      :icon="Download"
                      @click="exportPlan(plan)"
                      title="导出" />
                    <el-button 
                      type="danger" 
                      size="small" 
                      link
                      :icon="Delete"
                      @click="handleDeletePlan(plan.id!)"
                      title="删除" />
                  </div>
                </div>
                <div class="plan-info">
                  <div class="plan-description" v-if="plan.description">
                    {{ plan.description }}
                  </div>
                  <div class="plan-meta">
                    <el-tag size="small" type="info">
                      {{ plan.api_ids.length }} 个接口
                    </el-tag>
                    <span class="plan-time">{{ formatTime(plan.updated_at) }}</span>
                  </div>
                </div>
              </div>
            </div>
          </el-scrollbar>
        </div>
      </el-aside>
    </el-container>

    <!-- 链接口编辑抽屉 -->
    <el-drawer 
      v-model="chainEditorVisible"
      title="链路接口编辑"
      size="70%"
      :with-header="false"
      append-to-body>
      <div class="chain-drawer-header">
        <div class="header-left">
          <span class="drawer-title">
            链路接口
            <strong v-if="activeChainIndex !== null">{{ activeChainIndexNumber + 1 }} / {{ chainApis.length }}</strong>
          </span>
          <div v-if="activeChainIndex !== null" class="chain-current-title">
            <el-tag :type="getMethodType(chainApis[activeChainIndexNumber].method)" size="small">
              {{ chainApis[activeChainIndexNumber].method }}
            </el-tag>
            <span class="chain-path">{{ chainApis[activeChainIndexNumber].path }}</span>
          </div>
        </div>
        <div class="chain-nav-actions">
          <el-button 
            size="small" 
            :disabled="activeChainIndex === null || activeChainIndexNumber === 0"
            @click="selectChainItem(activeChainIndexNumber - 1)">
            上一个
          </el-button>
          <el-button 
            size="small" 
            :disabled="activeChainIndex === null || activeChainIndexNumber === chainApis.length - 1"
            @click="selectChainItem(activeChainIndexNumber + 1)">
            下一个
          </el-button>
          <el-button 
            size="small" 
            type="primary"
            :disabled="activeChainIndex === null"
            @click="saveCurrentChainItem">
            保存当前接口
          </el-button>
        </div>
      </div>

      <div v-if="activeChainIndex === null" class="chain-empty-edit">
        <el-empty description="从左侧选择接口进行编辑" :image-size="80" />
      </div>
      <div v-else class="chain-drawer-content">
        <div class="chain-editor-left">
          <div class="chain-section-title">接口详情</div>
          <el-descriptions :column="2" border size="small" class="chain-info">
            <el-descriptions-item label="路径">{{ chainApis[activeChainIndexNumber].path }}</el-descriptions-item>
            <el-descriptions-item label="方法">
              <el-tag :type="getMethodType(chainApis[activeChainIndexNumber].method)" size="small">
                {{ chainApis[activeChainIndexNumber].method }}
              </el-tag>
            </el-descriptions-item>
            <el-descriptions-item label="描述" :span="2">
              {{ chainApis[activeChainIndexNumber].summary || '暂无描述' }}
            </el-descriptions-item>
          </el-descriptions>

          <div class="chain-section-title">请求配置</div>
          <el-tabs type="border-card" v-model="chainItemActiveTab[activeChainIndexNumber]">
            <el-tab-pane label="Header" name="headers">
              <div class="chain-params-section">
                <div class="chain-ref-hint">
                  <span>引用说明</span>
                  <el-tooltip effect="dark" placement="top" width="400">
                    <template #content>
                      <div style="white-space: pre-line; font-size: 12px; line-height: 1.8;">{{ referenceHelpContent }}</div>
                    </template>
                    <el-icon style="cursor: pointer; color: #909399;" :size="16">
                      <QuestionFilled />
                    </el-icon>
                  </el-tooltip>
                </div>
                <el-input 
                  v-model="chainItemParams[activeChainIndexNumber].headers" 
                  type="textarea" 
                  :rows="14"
                  placeholder='{"Authorization": "$.prev[0].response_headers.token", "Content-Type": "application/json"}' />
              </div>
            </el-tab-pane>

            <el-tab-pane label="Query" name="query">
              <div class="chain-params-section">
                <div class="chain-ref-hint">
                  <span>引用说明</span>
                  <el-tooltip effect="dark" placement="top" width="400">
                    <template #content>
                      <div style="white-space: pre-line; font-size: 12px; line-height: 1.8;">{{ referenceHelpContent }}</div>
                    </template>
                    <el-icon style="cursor: pointer; color: #909399;" :size="16">
                      <QuestionFilled />
                    </el-icon>
                  </el-tooltip>
                </div>
                <el-input 
                  v-model="chainItemParams[activeChainIndexNumber].query" 
                  type="textarea" 
                  :rows="14"
                  placeholder='{"key": "value", "id": "$.prev[0].response_body.id"}' />
              </div>
            </el-tab-pane>

            <el-tab-pane label="Body" name="body" v-if="['POST', 'PUT', 'PATCH'].includes(chainApis[activeChainIndexNumber].method)">
              <div class="chain-params-section">
                <div class="chain-ref-hint">
                  <span>引用说明</span>
                  <el-tooltip effect="dark" placement="top" width="400">
                    <template #content>
                      <div style="white-space: pre-line; font-size: 12px; line-height: 1.8;">{{ referenceHelpContent }}</div>
                    </template>
                    <el-icon style="cursor: pointer; color: #909399;" :size="16">
                      <QuestionFilled />
                    </el-icon>
                  </el-tooltip>
                </div>
                <el-input 
                  v-model="chainItemParams[activeChainIndexNumber].body" 
                  type="textarea" 
                  :rows="16"
                  placeholder='{"key": "value", "userId": "$.api[1].response_body.data.id"}' />
              </div>
            </el-tab-pane>

            <el-tab-pane label="Assertion" name="assertions">
              <div class="chain-assertions-section">
                <div class="assertions-list">
                  <div 
                    v-for="(assertion, aIndex) in chainItemAssertions[activeChainIndexNumber]" 
                    :key="aIndex" 
                    class="assertion-item">
                    <div class="assertion-row">
                      <div class="assertion-field">
                        <el-select 
                          v-model="assertion.type" 
                          placeholder="选择类型" 
                          size="default"
                          style="width: 140px;">
                          <el-option label="状态码" value="status_code" />
                          <el-option label="JSON路径" value="json_path" />
                          <el-option label="响应时间" value="response_time" />
                          <el-option label="包含" value="contains" />
                        </el-select>
                      </div>
                      <div class="assertion-field" v-if="assertion.type === 'json_path'">
                        <el-input 
                          v-model="assertion.path" 
                          placeholder="例如: data.id"
                          clearable
                          size="default"
                          style="width: 200px;">
                          <template #prepend>$.</template>
                        </el-input>
                      </div>
                      <div class="assertion-field">
                        <el-select 
                          v-model="assertion.operator" 
                          placeholder="选择操作符" 
                          size="default"
                          style="width: 120px;">
                          <el-option label="等于" value="eq" />
                          <el-option label="不等于" value="ne" />
                          <el-option label="大于" value="gt" />
                          <el-option label="小于" value="lt" />
                          <el-option label="包含" value="contains" />
                          <el-option label="不包含" value="not_contains" />
                        </el-select>
                      </div>
                      <div class="assertion-field">
                        <el-input 
                          v-model="assertion.expected" 
                          :placeholder="getExpectedPlaceholder(assertion.type)"
                          clearable
                          size="default"
                          style="width: 150px;" />
                      </div>
                      <div class="assertion-actions-inline">
                        <el-button 
                          type="primary" 
                          size="small" 
                          :icon="Plus"
                          @click="insertChainAssertion(activeChainIndexNumber, aIndex + 1)"
                          circle 
                          title="在此行后新增断言" />
                        <el-button 
                          type="danger" 
                          size="small" 
                          :icon="Delete"
                          @click="removeChainAssertion(activeChainIndexNumber, aIndex)"
                          circle 
                          title="删除此断言" />
                      </div>
                    </div>
                    <div v-if="assertion.result !== undefined" class="assertion-result">
                      <el-tag :type="assertion.result ? 'success' : 'danger'" size="large">
                        <span style="font-weight: 600;">
                          {{ assertion.result ? '✓ 通过' : '✗ 失败' }}
                        </span>
                      </el-tag>
                      <div v-if="!assertion.result" class="assertion-error">
                        <div>实际值: {{ assertion.actualValue }} | 预期值: {{ (assertion as any).resolvedExpected ?? assertion.expected }}</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </el-tab-pane>
          </el-tabs>
        </div>

        <div class="chain-editor-right">
          <div class="chain-section-title">执行结果</div>
          <div v-if="currentChainResult" class="chain-result-panel">
            <div class="result-summary">
              <el-tag :type="currentChainResult.success ? 'success' : 'danger'" size="small">
                {{ currentChainResult.success ? '成功' : '失败' }}
              </el-tag>
              <span class="status-chip">状态码: {{ currentChainResult.response?.response_status || '-' }}</span>
              <span class="status-chip">耗时: {{ currentChainResult.response?.response_time || 0 }}ms</span>
              <el-tag 
                v-if="(currentChainResult as any).assertionSummary && (currentChainResult as any).assertionSummary.total > 0" 
                :type="(currentChainResult as any).assertionSummary.failed === 0 ? 'success' : 'danger'"
                size="small">
                Assertion: {{ (currentChainResult as any).assertionSummary.passed }}/{{ (currentChainResult as any).assertionSummary.total }}"
              </el-tag>
              <el-button 
                size="small" 
                link 
                type="primary"
                @click="openResultDrawer(activeChainIndexNumber)">
                查看完整详情
              </el-button>
            </div>
            <div class="result-section">
              <h4>响应体</h4>
              <pre class="json-display">{{ formatJSON(currentChainResult.response?.response_body) }}</pre>
            </div>
            <div class="result-section">
              <h4>响应头</h4>
              <pre class="json-display">{{ formatJSON(currentChainResult.response?.response_headers) }}</pre>
            </div>
            <div class="result-section" v-if="currentChainResult.message">
              <h4>执行信息</h4>
              <div class="result-message">{{ currentChainResult.message }}</div>
            </div>
          </div>
          <div v-else class="chain-empty-result">
            <el-empty description="暂无执行结果" :image-size="60" />
          </div>
        </div>
      </div>
    </el-drawer>

    <!-- 上传Swagger对话框 -->
    <el-dialog v-model="showSwaggerDialog" title="上传Swagger文件" width="500px">
      <el-upload
        ref="swaggerUploadRef"
        drag
        :auto-upload="false"
        :limit="1"
        accept=".json"
        :on-change="handleSwaggerFileChange">
        <el-icon class="el-icon--upload"><upload-filled /></el-icon>
        <div class="el-upload__text">
          拖拽文件到此处或<em>点击上传</em>
        </div>
        <template #tip>
          <div class="el-upload__tip">支持Swagger v2/v3格式的JSON文件</div>
        </template>
      </el-upload>

      <template #footer>
        <el-button @click="showSwaggerDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSwaggerUpload" :loading="uploading">
          确定上传
        </el-button>
      </template>
    </el-dialog>

    <!-- 上传Markdown对话框 -->
    <!-- 生成变量对话框 -->
    <el-dialog v-model="showGenerateVarDialog" :title="generatedValueLabel" width="400px">
      <div style="margin-bottom: 20px;">
        <el-input
          v-model="generatedValue"
          readonly
          type="textarea"
          :rows="3"
          style="font-family: monospace;" />
      </div>
      <template #footer>
        <el-button type="primary" @click="copyGeneratedValue">
          复制
        </el-button>
        <el-button @click="showGenerateVarDialog = false">
          关闭
        </el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showMarkdownDialog" title="上传Markdown文档" width="500px">
      <el-upload
        ref="markdownUploadRef"
        drag
        :auto-upload="false"
        :limit="1"
        accept=".md,.markdown"
        :on-change="handleMarkdownFileChange">
        <el-icon class="el-icon--upload"><upload-filled /></el-icon>
        <div class="el-upload__text">
          拖拽文件到此处或<em>点击上传</em>
        </div>
        <template #tip>
          <div class="el-upload__tip">支持Markdown格式的接口文档</div>
        </template>
      </el-upload>

      <template #footer>
        <el-button @click="showMarkdownDialog = false">取消</el-button>
        <el-button type="primary" @click="handleMarkdownUpload" :loading="uploading">
          确定上传
        </el-button>
      </template>
    </el-dialog>

    <!-- 添加测试数据对话框 -->
    <el-dialog v-model="showTestDataDialog" title="添加测试数据" width="700px">
      <el-form :model="testDataForm" label-width="120px">
        <el-form-item label="数据名称">
          <el-input v-model="testDataForm.name" placeholder="请输入测试数据名称" />
        </el-form-item>
        
        <!-- 前置接口配置 -->
        <el-divider content-position="left">
          <el-icon><Operation /></el-icon>
          <span style="margin-left: 8px;">前置接口配置（可选）</span>
        </el-divider>
        
        <el-form-item label="前置接口">
          <el-select 
            v-model="testDataForm.pre_request_api_id" 
            placeholder="选择前置接口（如登录接口）"
            clearable
            filterable
            style="width: 100%">
            <el-option 
              v-for="api in apis" 
              :key="api.id" 
              :label="`${api.method} ${api.path} - ${api.summary || api.operation_id}`" 
              :value="api.id" />
          </el-select>
          <div class="form-tip">
            前置接口会在当前接口执行前先执行，通常用于获取登录 token
          </div>
        </el-form-item>
        
        <el-form-item label="前置接口测试数据" v-if="testDataForm.pre_request_api_id">
          <el-select 
            v-model="testDataForm.pre_request_test_data_id" 
            placeholder="选择该前置接口的测试数据（可选）"
            clearable
            style="width: 100%">
            <el-option 
              v-for="td in getTestDataByApiId(testDataForm.pre_request_api_id)" 
              :key="td.id" 
              :label="td.name" 
              :value="td.id" />
          </el-select>
        </el-form-item>
        
        <el-form-item label="变量提取规则" v-if="testDataForm.pre_request_api_id">
          <div class="variable-extractions">
            <div v-for="(path, varName, index) in testDataForm.variable_extractions" :key="index" class="extraction-row">
              <el-input 
                v-model="Object.keys(testDataForm.variable_extractions)[index]" 
                placeholder="变量名（如: accessToken）"
                style="width: 35%"
                @blur="handleVariableNameChange(index, $event.target.value)" />
              <el-input 
                v-model="testDataForm.variable_extractions[varName]" 
                placeholder="JSONPath（如: $.data.accessToken）"
                style="width: 55%; margin-left: 10px" />
              <el-button 
                type="danger" 
                size="small"
                icon="Delete"
                circle
                @click="removeVariableExtraction(varName)"
                style="margin-left: 10px" />
            </div>
            <el-button 
              type="primary" 
              size="small"
              icon="Plus"
              @click="addVariableExtraction"
              style="margin-top: 10px">
              添加变量提取
            </el-button>
          </div>
          <div class="form-tip">
            从前置接口响应中提取变量，然后在当前接口中使用 <code v-pre>{{variableName}}</code> 引用
          </div>
        </el-form-item>
        
        <el-divider />
        
        <el-form-item label="Query参数">
          <el-input 
            v-model="testDataForm.query_params" 
            type="textarea" 
            :rows="3"
            placeholder='{"key": "value"}' />
        </el-form-item>
        <el-form-item label="Path参数">
          <el-input 
            v-model="testDataForm.path_params" 
            type="textarea" 
            :rows="3"
            placeholder='{"id": "123"}' />
        </el-form-item>
        <el-form-item label="请求头">
          <el-input 
            v-model="testDataForm.headers" 
            type="textarea" 
            :rows="3"
            placeholder='{"Authorization": "Bearer {{accessToken}}"}' />
          <div class="form-tip">
            可以使用 <code v-pre>{{variableName}}</code> 引用前置接口提取的变量
          </div>
        </el-form-item>
        <el-form-item label="请求体" v-if="selectedApi && ['POST', 'PUT', 'PATCH'].includes(selectedApi.method)">
          <el-input 
            v-model="testDataForm.body" 
            type="textarea" 
            :rows="6"
            placeholder='{"key": "value"}' />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showTestDataDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSaveTestData">保存</el-button>
      </template>
    </el-dialog>

    <!-- 添加/编辑环境对话框 -->
    <el-dialog v-model="showEnvDialog" :title="envDialogTitle" width="500px">
      <el-form :model="envForm" label-width="100px">
        <el-form-item label="环境名称" required>
          <el-input v-model="envForm.name" placeholder="例如：开发环境、测试环境" />
        </el-form-item>
        <el-form-item label="基础URL" required>
          <el-input v-model="envForm.base_url" placeholder="http://192.168.60.219:48080" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input 
            v-model="envForm.description" 
            type="textarea" 
            :rows="3"
            placeholder="环境描述信息（可选）" />
        </el-form-item>
        <el-form-item label="公共请求头">
          <el-input 
            v-model="envForm.headers" 
            type="textarea" 
            :rows="4"
            placeholder='{"Content-Type": "application/json"}' />
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showEnvDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSaveEnvironment">保存</el-button>
      </template>
    </el-dialog>

    <!-- 保存串联方案对话框 -->
    <el-dialog v-model="showSavePlanDialog" :title="editingPlanId ? '编辑串联方案' : '保存串联方案'" width="500px">
      <el-form :model="planForm" label-width="80px">
        <el-form-item label="方案名称" required>
          <el-input v-model="planForm.name" placeholder="请输入方案名称" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input 
            v-model="planForm.description" 
            type="textarea" 
            :rows="3"
            placeholder="方案描述（可选）" />
        </el-form-item>
        <el-form-item label="接口列表">
          <el-tag 
            v-for="(apiId, index) in chainApis.map(a => a.id)" 
            :key="index"
            size="small"
            style="margin-right: 5px; margin-bottom: 5px;">
            {{ apis.find(a => a.id === apiId)?.summary || apis.find(a => a.id === apiId)?.path }}
          </el-tag>
          <div style="margin-top: 10px; font-size: 12px; color: #909399;">
            共 {{ chainApis.length }} 个接口
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showSavePlanDialog = false">取消</el-button>
        <el-button type="primary" @click="handleSavePlan" :disabled="!planForm.name">
          {{ editingPlanId ? '更新' : '保存' }}
        </el-button>
      </template>
    </el-dialog>

    <!-- 全局前置操作对话框 -->
    <el-dialog v-model="showGlobalPreRequestDialog" title="全局前置操作" width="700px" class="global-pre-request-dialog">
      <el-alert 
        type="info" 
        :closable="false"
        style="margin-bottom: 20px; margin-left: 0; margin-right: 0;">
        <template #title>
          配置全局前置操作，一键同步键值对到所有测试数据中
        </template>
      </el-alert>
      
      <el-tabs v-model="globalPreRequestMode" class="global-pre-request-tabs">
        <!-- 模式1：通过接口获取 -->
        <el-tab-pane label="接口获取键值对" name="api">
          <el-form label-width="140px" style="margin-top: 20px; margin-left: 0;" class="global-pre-request-form">
            <el-form-item label="选择接口">
              <el-select 
                v-model="globalPreRequest.api_id" 
                placeholder="选择接口" 
                filterable
                style="width: 100%"
                @change="handleGlobalPreApiChange">
                <el-option 
                  v-for="api in apis" 
                  :key="api.id" 
                  :label="`${api.path} - ${api.summary || api.operation_id}`" 
                  :value="api.id" />
              </el-select>
            </el-form-item>
            
            <el-form-item label="选择环境" v-if="globalPreRequest.api_id">
              <el-select 
                v-model="globalPreRequest.environment_id" 
                placeholder="选择执行环境" 
                style="width: 100%">
                <el-option 
                  v-for="env in environments" 
                  :key="env.id" 
                  :label="env.name" 
                  :value="env.id">
                  <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span>{{ env.name }}</span>
                    <span style="color: #909399; font-size: 12px; margin-left: 10px;">{{ env.base_url }}</span>
                  </div>
                </el-option>
              </el-select>
            </el-form-item>
            
            <el-form-item label="测试数据" v-if="globalPreRequest.api_id">
              <el-select 
                v-model="globalPreRequest.test_data_id" 
                placeholder="选择测试数据（默认使用第一条）" 
                style="width: 100%"
                @change="handleGlobalPreTestDataChange">
                <el-option 
                  v-for="td in globalPreTestDataList" 
                  :key="td.id" 
                  :label="td.name || `测试数据 #${td.id}`" 
                  :value="td.id" />
              </el-select>
            </el-form-item>
            
            <el-form-item label="请求参数" v-if="globalPreRequest.api_id">
              <el-tabs v-model="globalPreParamsTab" style="width: 100%;">
                <el-tab-pane label="Header" name="headers">
                  <el-input 
                    v-model="globalPreRequest.requestHeaders" 
                    type="textarea" 
                    :rows="6"
                    placeholder='{"Content-Type": "application/json", "Authorization": "Bearer xxx"}' />
                </el-tab-pane>
                <el-tab-pane label="Query" name="query">
                  <el-input 
                    v-model="globalPreRequest.queryParams" 
                    type="textarea" 
                    :rows="6"
                    placeholder='{"page": 1, "size": 10}' />
                </el-tab-pane>
                <el-tab-pane label="Body" name="body">
                  <el-input 
                    v-model="globalPreRequest.requestBody" 
                    type="textarea" 
                    :rows="6"
                    placeholder='{"username": "admin", "password": "123456"}' />
                </el-tab-pane>
                <el-tab-pane label="Path" name="path">
                  <el-input 
                    v-model="globalPreRequest.pathParams" 
                    type="textarea" 
                    :rows="6"
                    placeholder='{"id": "123"}' />
                </el-tab-pane>
              </el-tabs>
            </el-form-item>
            
        <el-form-item>
          <el-button 
            type="info" 
            @click="handleSaveGlobalPreConfig"
            :loading="executingGlobalPre">
            保存配置
          </el-button>
          <el-button 
            type="primary" 
            @click="handleExecutePreRequestApi"
            :loading="executingGlobalPre"
            style="margin-left: 10px;">
            执行接口
          </el-button>
          <span v-if="globalPreRequestResult" style="margin-left: 10px; color: #67c23a;">
            ✓ 接口执行成功
          </span>
        </el-form-item>
        
            <el-form-item label="执行结果" v-if="globalPreRequestResult">
              <el-input 
                :model-value="JSON.stringify(globalPreRequestResult.response_body, null, 2)" 
                type="textarea" 
                :rows="8"
                readonly />
            </el-form-item>
            
            <el-form-item label="变量提取规则" v-if="globalPreRequestResult">
              <div style="width: 100%;">
                <div v-for="(path, varName, index) in globalPreRequest.extractions" :key="index" style="display: flex; align-items: center; margin-bottom: 10px;">
                  <el-input 
                    v-model="Object.keys(globalPreRequest.extractions)[index]" 
                    placeholder="变量名（如: accessToken）"
                    style="width: 40%"
                    @blur="handleGlobalExtractionNameChange(index, $event.target.value)" />
                  <el-input 
                    v-model="globalPreRequest.extractions[varName]" 
                    placeholder="JSONPath（如: $.data.accessToken）"
                    style="width: 50%; margin-left: 10px" />
                  <el-button 
                    type="danger" 
                    size="small"
                    icon="Delete"
                    circle
                    @click="removeGlobalExtraction(varName)"
                    style="margin-left: 10px" />
                </div>
                <el-button 
                  type="primary" 
                  size="small"
                  icon="Plus"
                  @click="addGlobalExtraction">
                  添加变量提取
                </el-button>
              </div>
              <div class="form-tip" style="margin-top: 8px;">
                从接口响应中提取变量，如 accessToken、userId 等
              </div>
            </el-form-item>
            
            <el-form-item label="同步键值对" v-if="globalPreRequestResult">
              <div style="width: 100%;">
                <div v-for="(item, index) in globalPreRequest.headers" :key="index" style="display: flex; align-items: center; margin-bottom: 10px;">
                  <el-input 
                    v-model="item.key" 
                    placeholder="键名（如: Authorization、tenant-id）"
                    style="width: 40%" />
                  <el-input 
                    v-model="item.value" 
                    placeholder="键值（如: Bearer {{accessToken}}）"
                    style="width: 50%; margin-left: 10px" />
                  <el-button 
                    type="danger" 
                    size="small"
                    icon="Delete"
                    circle
                    @click="removeGlobalHeader(index)"
                    style="margin-left: 10px" />
                </div>
                <el-button 
                  type="primary" 
                  size="small"
                  icon="Plus"
                  @click="addGlobalHeader">
                  添加键值对
                </el-button>
              </div>
              <div class="form-tip" style="margin-top: 8px;">
                配置要同步的键值对，可使用 <code v-pre>{{variableName}}</code> 引用提取的变量
              </div>
            </el-form-item>
            
            <el-divider v-if="globalPreRequestResult" />
            
            <div style="text-align: center;" v-if="globalPreRequestResult">
              <el-button 
                type="success" 
                @click="handleSyncExtractedVariables"
                size="large">
                同步到所有测试数据
              </el-button>
            </div>
          </el-form>
        </el-tab-pane>
        
        <!-- 模式2：手动输入 -->
        <el-tab-pane label="手动输入键值对" name="manual">
          <el-form label-width="140px" style="margin-top: 20px; margin-left: 0;" class="global-pre-request-form">
            <el-form-item label="键值对">
              <div style="width: 100%;">
                <div v-for="(item, index) in globalManualHeaders" :key="index" style="display: flex; align-items: center; margin-bottom: 10px;">
                  <el-input 
                    v-model="item.key" 
                    placeholder="键名（如: Authorization、tenant-id）"
                    style="width: 40%" />
                  <el-input 
                    v-model="item.value" 
                    placeholder="键值（如: Bearer xxx、12345）"
                    style="width: 50%; margin-left: 10px" />
                  <el-button 
                    type="danger" 
                    size="small"
                    icon="Delete"
                    circle
                    @click="removeManualHeader(index)"
                    style="margin-left: 10px" />
                </div>
                <el-button 
                  type="primary" 
                  size="small"
                  icon="Plus"
                  @click="addManualHeader">
                  添加键值对
                </el-button>
              </div>
              <div class="form-tip" style="margin-top: 8px;">
                直接输入要同步的键值对，可用于 Header、Query 参数等
              </div>
            </el-form-item>
            
            <el-divider />
            
            <div style="text-align: center;">
              <el-button 
                type="success" 
                @click="handleSyncManualHeaders"
                size="large">
                同步到所有测试数据
              </el-button>
            </div>
          </el-form>
        </el-tab-pane>
      </el-tabs>
    </el-dialog>

    <!-- 同步接口环境选择对话框 -->
    <el-dialog v-model="showSyncEnvDialog" title="选择同步环境" width="500px">
      <el-alert 
        type="warning" 
        :closable="false"
        style="margin-bottom: 20px;">
        <template #title>
          将从选定环境的 Swagger 文档同步接口，会删除现有接口并导入新接口
        </template>
      </el-alert>
      
      <el-form label-width="100px">
        <el-form-item label="选择环境" required>
          <el-select 
            v-model="syncEnvId" 
            placeholder="请选择要同步的环境" 
            style="width: 100%">
            <el-option 
              v-for="env in environments" 
              :key="env.id" 
              :label="env.name" 
              :value="env.id">
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <span>{{ env.name }}</span>
                <span style="color: #909399; font-size: 12px; margin-left: 10px;">{{ env.base_url }}</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="Swagger路径">
          <el-input v-model="syncSwaggerPath" placeholder="/v3/api-docs" />
          <div style="margin-top: 5px; font-size: 12px; color: #909399;">
            完整URL: {{ syncFullUrl }}
          </div>
        </el-form-item>
      </el-form>

      <template #footer>
        <el-button @click="showSyncEnvDialog = false">取消</el-button>
        <el-button type="primary" @click="handleConfirmSync" :loading="syncing" :disabled="!syncEnvId">
          开始同步
        </el-button>
      </template>
    </el-dialog>

    <!-- 执行结果右侧抽屉 -->
    <el-drawer
      v-model="resultDrawerVisible"
      :title="resultDrawerTitle"
      size="45%"
      append-to-body>
      <div v-if="resultDrawerContent">
        <div class="result-summary" style="margin-bottom: 12px;">
          <el-tag :type="resultDrawerContent.success ? 'success' : 'danger'" size="small">
            {{ resultDrawerContent.success ? '成功' : '失败' }}
          </el-tag>
          <span>状态码: {{ resultDrawerContent.response?.response_status || '-' }}</span>
          <span>耗时: {{ resultDrawerContent.response?.response_time || 0 }}ms</span>
          <el-tag 
            v-if="resultDrawerContent.assertionSummary && resultDrawerContent.assertionSummary.total > 0" 
            :type="resultDrawerContent.assertionSummary.failed === 0 ? 'success' : 'danger'"
            size="small">
            Assertion: {{ resultDrawerContent.assertionSummary.passed }}/{{ resultDrawerContent.assertionSummary.total }}
          </el-tag>
        </div>
        <el-tabs type="border-card" size="small">
          <el-tab-pane label="执行入参">
            <div v-if="resultDrawerContent.executedParams">
              <div v-if="resultDrawerContent.executedParams.query_params" class="param-block">
                <div class="param-label">Query参数：</div>
                <div class="param-actions">
                  <el-button link type="primary" size="small" @click="copyText(toJSONString(resultDrawerContent.executedParams.query_params), 'Query参数')">复制</el-button>
                </div>
                <pre class="json-display">{{ formatJSON(resultDrawerContent.executedParams.query_params) }}</pre>
              </div>
              <div v-if="resultDrawerContent.executedParams.body" class="param-block">
                <div class="param-label">Body：</div>
                <div class="param-actions">
                  <el-button link type="primary" size="small" @click="copyText(toJSONString(resultDrawerContent.executedParams.body), 'Body')">复制</el-button>
                </div>
                <pre class="json-display">{{ formatJSON(resultDrawerContent.executedParams.body) }}</pre>
              </div>
              <div v-if="resultDrawerContent.executedParams.headers" class="param-block">
                <div class="param-label">Headers：</div>
                <div class="param-actions">
                  <el-button link type="primary" size="small" @click="copyText(toJSONString(resultDrawerContent.executedParams.headers), 'Headers')">复制</el-button>
                </div>
                <pre class="json-display">{{ formatJSON(resultDrawerContent.executedParams.headers) }}</pre>
              </div>
              <div v-if="!resultDrawerContent.executedParams.query_params && !resultDrawerContent.executedParams.body && !resultDrawerContent.executedParams.headers">
                <el-empty description="无入参" :image-size="60" />
              </div>
            </div>
            <div v-else>
              <el-empty description="未记录入参信息" :image-size="60" />
            </div>
          </el-tab-pane>
          <el-tab-pane label="响应体">
            <div class="param-actions" style="margin-bottom: 6px;">
              <el-button link type="primary" size="small" @click="copyText(toJSONString(resultDrawerContent.response?.response_body), '响应体')">复制</el-button>
            </div>
            <pre class="json-display">{{ formatJSON(resultDrawerContent.response?.response_body) }}</pre>
          </el-tab-pane>
          <el-tab-pane label="响应头">
            <div class="param-actions" style="margin-bottom: 6px;">
              <el-button link type="primary" size="small" @click="copyText(toJSONString(resultDrawerContent.response?.response_headers), '响应头')">复制</el-button>
            </div>
            <pre class="json-display">{{ formatJSON(resultDrawerContent.response?.response_headers) }}</pre>
          </el-tab-pane>
        </el-tabs>
      </div>
      <div v-else>
        <el-empty description="暂无结果" :image-size="60" />
      </div>
    </el-drawer>

    <!-- 执行详情抽屉 -->
    <el-drawer
      v-model="showExecutionDetailDrawer"
      title="执行详情"
      size="90%"
      :show-close="false"
      append-to-body>
      <template #header>
        <span>执行详情</span>
      </template>
      <div class="execution-detail-container">
        <el-scrollbar height="calc(100vh - 100px)">
          <div
            v-for="(result, index) in chainResults"
            :key="index"
            class="execution-detail-item">
            <div class="execution-detail-header">
              <div class="execution-detail-title">
                <span class="execution-index">{{ index + 1 }} / {{ chainResults.length }}</span>
                <el-tag :type="getMethodType(chainApis[index]?.method)" size="small">
                  {{ chainApis[index]?.method }}
                </el-tag>
                <span class="execution-path">{{ chainApis[index]?.path }}</span>
              </div>
              <el-tag :type="result.success ? 'success' : 'danger'" size="small">
                {{ result.success ? '成功' : '失败' }}
              </el-tag>
            </div>
            <div class="execution-detail-content">
              <!-- 左半部分：请求 -->
              <div class="execution-detail-request">
                <div class="request-section">
                  <div v-if="result.executedParams?.query_params" class="param-section">
                    <div class="param-header">
                      <strong>Query参数</strong>
                      <el-button link type="primary" size="small" @click="copyText(toJSONString(result.executedParams.query_params), 'Query参数')">复制</el-button>
                    </div>
                    <pre class="json-display">{{ formatJSON(result.executedParams.query_params) }}</pre>
                  </div>
                  <div v-if="result.executedParams?.headers" class="param-section">
                    <div class="param-header">
                      <strong>Headers</strong>
                      <el-button link type="primary" size="small" @click="copyText(toJSONString(result.executedParams.headers), 'Headers')">复制</el-button>
                    </div>
                    <pre class="json-display">{{ formatJSON(result.executedParams.headers) }}</pre>
                  </div>
                  <div v-if="result.executedParams?.body" class="param-section">
                    <div class="param-header">
                      <strong>Body</strong>
                      <el-button link type="primary" size="small" @click="copyText(toJSONString(result.executedParams.body), 'Body')">复制</el-button>
                    </div>
                    <pre class="json-display">{{ formatJSON(result.executedParams.body) }}</pre>
                  </div>
                  <div v-if="!result.executedParams?.query_params && !result.executedParams?.headers && !result.executedParams?.body" class="param-section">
                    <div class="empty-params">无请求参数</div>
                  </div>
                </div>
              </div>
              <!-- 右半部分：响应 -->
              <div class="execution-detail-response">
                <div class="response-section">
                  <div class="param-section">
                    <div class="param-header">
                      <strong>状态码</strong>
                      <span>{{ result.response?.response_status || '-' }}</span>
                    </div>
                  </div>
                  <div v-if="result.response?.response_headers" class="param-section">
                    <div class="param-header">
                      <strong>响应头</strong>
                      <el-button link type="primary" size="small" @click="copyText(toJSONString(result.response.response_headers), '响应头')">复制</el-button>
                    </div>
                    <pre class="json-display">{{ formatJSON(result.response.response_headers) }}</pre>
                  </div>
                  <div v-if="result.response?.response_body" class="param-section">
                    <div class="param-header">
                      <strong>响应体</strong>
                      <el-button link type="primary" size="small" @click="copyText(toJSONString(result.response.response_body), '响应体')">复制</el-button>
                    </div>
                    <pre class="json-display">{{ formatJSON(result.response.response_body) }}</pre>
                  </div>
                  <div v-if="!result.response?.response_headers && !result.response?.response_body" class="param-section">
                    <div class="empty-params">无响应数据</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div v-if="chainResults.length === 0" class="empty-execution">
            <el-empty description="暂无执行结果" :image-size="80" />
          </div>
        </el-scrollbar>
      </div>
    </el-drawer>

  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick } from 'vue'
import { ElMessage, ElMessageBox, type UploadFile } from 'element-plus'
import { Upload, Delete, VideoPlay, Plus, UploadFilled, MagicStick, Edit, InfoFilled, Search, Refresh, Connection, Top, Bottom, Close, Loading, SuccessFilled, CircleCloseFilled, Setting, DataAnalysis, List, FolderAdd, ArrowDown, ArrowUp, Document, Collection, Check, Operation, QuestionFilled, Star, DocumentCopy, Download } from '@element-plus/icons-vue'
import * as api from '@/api/services'
import type { API, Environment, TestData, ExecutionRecord } from '@/api/types'

// 数据
const apis = ref<API[]>([])
const environments = ref<Environment[]>([])
const selectedApi = ref<API | null>(null)
const selectedEnvironment = ref<number>()
const testDataList = ref<TestData[]>([])
const selectedTestData = ref<number | null>(null)
const executionResult = ref<ExecutionRecord | null>(null)

// UI状态
const showSwaggerDialog = ref(false)
const showMarkdownDialog = ref(false)
const showTestDataDialog = ref(false)
const showEnvDialog = ref(false)
const editingEnvId = ref<number | null>(null)
const uploading = ref(false)
const executing = ref(false)
const batchExecuting = ref(false)
const syncing = ref(false)
const swaggerFile = ref<File | null>(null)
const testMode = ref<'single' | 'chain'>('single')

// 串联执行相关
const chainApis = ref<API[]>([])
const chainEnvironment = ref<number>()
const chainStopOnError = ref(true)
const chainDelay = ref(500)
const chainExecuting = ref(false)
const currentExecutingIndex = ref(-1)
const chainResults = ref<Array<{success: boolean, message: string, data?: any, response?: any}>>([])
const activeChainIndex = ref<number | null>(null) // 当前在中间面板编辑的链条接口
const chainEditorVisible = ref(false)
const markdownFile = ref<File | null>(null)
const activeTab = ref('headers')
const filterMethod = ref('')

// 断言相关
interface Assertion {
  type: 'status_code' | 'json_path' | 'response_time' | 'contains'
  path?: string
  operator: 'eq' | 'ne' | 'gt' | 'lt' | 'contains' | 'not_contains'
  expected: string
  result?: boolean
  actualValue?: string
}
// 创建默认断言（一行状态码）
const createDefaultAssertion = (): Assertion => ({
  type: 'status_code',
  operator: 'eq',
  expected: '200'
})

const assertions = ref<Assertion[]>([createDefaultAssertion()])

// 串联执行相关：展开状态和参数配置
const expandedChainItems = ref<Record<number, boolean>>({})
const chainItemActiveTab = ref<Record<number, string>>({})
const chainItemParams = ref<Record<number, {query: string, body: string, headers: string}>>({})
const chainItemAssertions = ref<Record<number, Assertion[]>>({})
const chainGlobalVars = ref<Array<{ key: string; value: string }>>([
  { key: '', value: '' }
])

// 生成变量对话框
const showGenerateVarDialog = ref(false)
const generatedValue = ref('')
const generatedValueLabel = ref('')

// 执行详情抽屉
const showExecutionDetailDrawer = ref(false)

// 生成UNIX时间戳
const generateTimestamp = () => {
  const timestamp = Math.floor(Date.now() / 1000)
  generatedValue.value = String(timestamp)
  generatedValueLabel.value = 'UNIX时间戳'
  showGenerateVarDialog.value = true
}

// 生成时间点（格式：20251212）
const generateDateString = () => {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const dateString = `${year}${month}${day}`
  generatedValue.value = dateString
  generatedValueLabel.value = '时间点'
  showGenerateVarDialog.value = true
}

// 复制生成的值
const copyGeneratedValue = async () => {
  try {
    await navigator.clipboard.writeText(generatedValue.value)
    ElMessage.success('已复制到剪贴板')
  } catch (e) {
    // 降级方案
    const textarea = document.createElement('textarea')
    textarea.value = generatedValue.value
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand('copy')
      ElMessage.success('已复制到剪贴板')
    } catch (err) {
      ElMessage.error('复制失败')
    } finally {
      document.body.removeChild(textarea)
    }
  }
}
const chainGlobalVarMap = computed(() => {
  const map: Record<string, any> = {}
  chainGlobalVars.value.forEach(({ key, value }) => {
    if (!key || !key.trim()) return  // 跳过空的key
    // 如果value为空字符串，也保存为空字符串
    if (value === '' || value.trim() === '') {
      map[key.trim()] = ''
      return
    }
    try {
      // 尝试解析为JSON
      map[key.trim()] = JSON.parse(value)
    } catch {
      // 解析失败，作为字符串保存
      map[key.trim()] = value
    }
  })
  return map
})
// 文本复制
const toJSONString = (val: any) => {
  if (val === undefined || val === null) return ''
  if (typeof val === 'string') return val
  try {
    return JSON.stringify(val, null, 2)
  } catch {
    return String(val)
  }
}
const copyText = async (text: string, label: string) => {
  const content = text ?? ''
  try {
    await navigator.clipboard.writeText(content)
    ElMessage.success(`${label}已复制`)
  } catch {
    const textarea = document.createElement('textarea')
    textarea.value = content
    textarea.style.position = 'fixed'
    textarea.style.opacity = '0'
    document.body.appendChild(textarea)
    textarea.select()
    try {
      document.execCommand('copy')
      ElMessage.success(`${label}已复制`)
    } catch (e) {
      ElMessage.error(`${label}复制失败`)
    } finally {
      document.body.removeChild(textarea)
    }
  }
}

// 初始化链接口参数
const initChainItemParams = (index: number) => {
  if (!chainItemParams.value[index]) {
    chainItemParams.value[index] = {
      query: '{}',
      body: '{}',
      headers: '{}'
    }
  }
  if (!chainItemAssertions.value[index]) {
    chainItemAssertions.value[index] = [createDefaultAssertion()]
  }
  if (!chainItemActiveTab.value[index]) {
    chainItemActiveTab.value[index] = 'headers'  // 默认激活 Header 标签页
  }
}

const ensureChainItemState = (index: number) => {
  if (index < 0) return
  initChainItemParams(index)
}

// 将测试数据填充到串联参数与断言（单向拷贝，不回写测试数据）
const fillChainFromTestData = (index: number, td: any, preserveAssertions: boolean = false) => {
  chainItemParams.value[index] = chainItemParams.value[index] || { query: '{}', body: '{}', headers: '{}' }
  let anyFilled = false

  if (td.query_params && Object.keys(td.query_params).length > 0) {
    chainItemParams.value[index].query = JSON.stringify(td.query_params, null, 2)
    anyFilled = true
  }
  if (td.body && Object.keys(td.body).length > 0) {
    chainItemParams.value[index].body = JSON.stringify(td.body, null, 2)
    anyFilled = true
  }
  if (td.headers && Object.keys(td.headers).length > 0) {
    chainItemParams.value[index].headers = JSON.stringify(td.headers, null, 2)
    anyFilled = true
  }

  // 只有在不保留断言且当前没有断言时，才从测试数据加载断言
  if (!preserveAssertions) {
    if (td.assertions && Array.isArray(td.assertions) && td.assertions.length > 0) {
      // 如果当前已经有断言，不覆盖
      if (!chainItemAssertions.value[index] || chainItemAssertions.value[index].length === 0) {
        chainItemAssertions.value[index] = td.assertions.map((a: any) => ({
          type: a.type || 'status_code',
          path: a.path || '',
          operator: a.operator || 'eq',
          expected: a.expected || ''
        }))
        anyFilled = true
      }
    } else if (!chainItemAssertions.value[index]) {
      chainItemAssertions.value[index] = [createDefaultAssertion()]
    }
  }

  return anyFilled
}

// 全局变量管理
const setChainGlobalVars = (vars?: Record<string, any>) => {
  if (!vars || Object.keys(vars).length === 0) {
    chainGlobalVars.value = [{ key: '', value: '' }]
    return
  }
  chainGlobalVars.value = Object.entries(vars).map(([key, val]) => ({
    key,
    value: typeof val === 'string' ? val : JSON.stringify(val, null, 2)
  }))
}

const addGlobalVar = () => {
  chainGlobalVars.value.push({ key: '', value: '' })
}

const removeGlobalVar = (index: number) => {
  chainGlobalVars.value.splice(index, 1)
  if (chainGlobalVars.value.length === 0) {
    chainGlobalVars.value.push({ key: '', value: '' })
  }
}

// 串联方案相关
const chainPlans = ref<api.ChainPlan[]>([])
const chainSearchKeyword = ref('')
const currentPlanId = ref<number>()
const showSavePlanDialog = ref(false)
const editingPlanId = ref<number>()
const planForm = ref({
  name: '',
  description: ''
})
const searchKeyword = ref('')
// 执行结果抽屉
const resultDrawerVisible = ref(false)
const resultDrawerTitle = ref('执行结果详情')
const resultDrawerContent = ref<any>(null)

// 引用说明提示内容
const referenceHelpContent = `💡 引用前置接口返回值：

• $.api[n].response_body.字段名
  按左侧编号引用第 n 个接口（编号从 1 开始）

• $.prev[n].response_body.字段名
  按执行结果数组索引引用（0 开始）

• $.prev[n].response_headers.字段名 / $.api[n].response_headers.字段名
  引用响应头字段

• $.prev[n].response_status / $.api[n].response_status
  引用状态码

• $.prev[n].response_body.list[0].name
  引用数组第一个元素

• $.prev[n].response_body.list.find(id=122).name
  从列表中查找 id=122 的项

• $.global.变量名
  引用全局变量

示例：
"Authorization": "$.api[1].response_body.token"

列表查找：
"name": "$.api[1].response_body.data.list.find(id=122).name"`

// 同步接口相关
const showSyncEnvDialog = ref(false)
const syncEnvId = ref<number>()
const syncSwaggerPath = ref('/v3/api-docs')

// 全局前置操作相关
const showGlobalPreRequestDialog = ref(false)
const globalPreRequestMode = ref('api') // 'api' 或 'manual'
const executingGlobalPre = ref(false)
const globalPreRequest = ref({
  api_id: null as number | null,
  environment_id: null as number | null,
  test_data_id: null as number | null,
  extractions: {} as Record<string, string>, // 变量名 -> JSONPath
  headers: [] as Array<{ key: string; value: string }>, // Header数组
  // 请求参数
  queryParams: '',
  pathParams: '',
  requestHeaders: '',
  requestBody: ''
})
const globalManualHeaders = ref<Array<{ key: string; value: string }>>([])
const globalPreRequestResult = ref<any>(null) // 执行结果
const globalPreTestDataList = ref<TestData[]>([]) // 选中接口的测试数据列表
const globalPreParamsTab = ref('headers') // 请求参数标签页

// 表单数据
const queryParamsText = ref('')
const pathParamsText = ref('')
const headersText = ref('')
const bodyText = ref('')
const formDataText = ref('')

// JSON格式化的placeholder文案
const headersPlaceholder = `{
  "Authorization": "Bearer token",
  "Content-Type": "application/json"
}`

const queryPlaceholder = `{
  "page": 1,
  "pageSize": 10
}`

const bodyPlaceholder = `{
  "name": "示例",
  "value": 123
}`

const pathPlaceholder = `{
  "id": "123"
}`

// Form Data 字段列表（类似 Postman）
const formDataFields = ref<Array<{
  key: string
  value: string
  type: 'text' | 'file'
  description: string
  fileName?: string
  file?: File
  fileList?: Array<any>
}>>([])


const testDataForm = ref({
  name: '',
  query_params: '',
  path_params: '',
  headers: '',
  body: '',
  // 前置接口配置
  pre_request_api_id: null,
  pre_request_test_data_id: null,
  variable_extractions: {}
})

const envForm = ref({
  name: '',
  base_url: '',
  description: '',
  headers: ''
})

// 创建一个新的空白流程
const handleCreateNewPlan = () => {
  testMode.value = 'chain'
  // 清空执行链与结果
  chainApis.value = []
  chainResults.value = []
  chainItemParams.value = {}
  chainItemActiveTab.value = {}
  expandedChainItems.value = {}
  chainItemAssertions.value = {}
  activeChainIndex.value = null
  currentExecutingIndex.value = -1

  // 重置方案状态
  currentPlanId.value = undefined
  editingPlanId.value = undefined
  planForm.value = { name: '', description: '' }

  // 重置全局配置
  chainGlobalVars.value = [{ key: '', value: '' }]
  chainEnvironment.value = undefined
  chainStopOnError.value = true
  chainDelay.value = 500

  ElMessage.success('已创建空白流程，可添加接口并保存方案')
}

// 计算属性
// 判断当前接口是否有 FormData
const hasFormData = computed(() => {
  if (!selectedApi.value) return false
  const reqBody = selectedApi.value.request_body
  if (!reqBody) return false
  return reqBody.type === 'formData' || 
         reqBody.content_type === 'multipart/form-data' ||
         reqBody.content_type === 'application/x-www-form-urlencoded'
})

// 获取收藏的接口ID列表
const getFavoriteApiIds = (): Set<number> => {
  try {
    const favorites = localStorage.getItem('api_favorites')
    return favorites ? new Set(JSON.parse(favorites)) : new Set()
  } catch {
    return new Set()
  }
}

// 保存收藏的接口ID列表
const saveFavoriteApiIds = (favoriteIds: Set<number>) => {
  try {
    localStorage.setItem('api_favorites', JSON.stringify(Array.from(favoriteIds)))
  } catch (error) {
    console.error('保存收藏状态失败:', error)
  }
}

// 切换收藏状态
const toggleFavorite = (apiItem: API) => {
  const favoriteIds = getFavoriteApiIds()
  if (favoriteIds.has(apiItem.id)) {
    favoriteIds.delete(apiItem.id)
    apiItem.is_favorite = false
  } else {
    favoriteIds.add(apiItem.id)
    apiItem.is_favorite = true
  }
  saveFavoriteApiIds(favoriteIds)
  ElMessage.success(apiItem.is_favorite ? '已收藏' : '已取消收藏')
}

// 过滤后的接口列表
const filteredApis = computed(() => {
  let result = apis.value
  
  // 按方法过滤
  if (filterMethod.value) {
    result = result.filter(api => api.method === filterMethod.value)
  }
  
  // 按关键词搜索
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase()
    result = result.filter(api => 
      api.path.toLowerCase().includes(keyword) ||
      (api.summary && api.summary.toLowerCase().includes(keyword)) ||
      (api.tags && api.tags.some(tag => tag.toLowerCase().includes(keyword)))
    )
  }
  
  // 收藏的接口置顶
  result = [...result].sort((a, b) => {
    const aFavorite = a.is_favorite ? 1 : 0
    const bFavorite = b.is_favorite ? 1 : 0
    return bFavorite - aFavorite
  })
  
  return result
})

// 过滤串联方案
const filteredChainPlans = computed(() => {
  if (!chainSearchKeyword.value) {
    return chainPlans.value
  }
  
  const keyword = chainSearchKeyword.value.toLowerCase()
  return chainPlans.value.filter(plan =>
    plan.name.toLowerCase().includes(keyword) ||
    (plan.description && plan.description.toLowerCase().includes(keyword))
  )
})

// 串联执行统计
const chainSuccessCount = computed(() => {
  return chainResults.value.filter(r => r.success).length
})

const chainFailCount = computed(() => {
  return chainResults.value.filter(r => !r.success).length
})

const chainProgress = computed(() => {
  if (chainApis.value.length === 0) return 0
  return Math.round((chainResults.value.length / chainApis.value.length) * 100)
})

// 当前选中的链接口及结果
const currentChainApi = computed(() => {
  if (activeChainIndex.value === null) return null
  return chainApis.value[activeChainIndex.value] || null
})

const currentChainResult = computed(() => {
  if (activeChainIndex.value === null) return null
  return chainResults.value[activeChainIndex.value] || null
})

const activeChainIndexNumber = computed(() => {
  return activeChainIndex.value ?? 0
})

const responseBodyText = computed(() => {
  if (!executionResult.value?.response_body) return ''
  if (typeof executionResult.value.response_body === 'string') {
    return executionResult.value.response_body
  }
  return JSON.stringify(executionResult.value.response_body, null, 2)
})

// 断言统计
const assertionSummary = computed(() => {
  const total = assertions.value.length
  const passed = assertions.value.filter(a => a.result === true).length
  const failed = assertions.value.filter(a => a.result === false).length
  return { total, passed, failed }
})

const envDialogTitle = computed(() => {
  return editingEnvId.value ? '修改环境配置' : '添加环境配置'
})

// 同步接口完整URL
const syncFullUrl = computed(() => {
  if (!syncEnvId.value) return ''
  const env = environments.value.find(e => e.id === syncEnvId.value)
  if (!env) return ''
  return env.base_url + syncSwaggerPath.value
})

const getFullEnvLabel = (env: Environment) => {
  return `${env.name} - ${env.base_url}`
}

// 链模式：保持选中项
watch(chainApis, (val) => {
  if (val.length === 0) {
    activeChainIndex.value = null
    return
  }
  if (activeChainIndex.value === null || activeChainIndex.value >= val.length) {
    activeChainIndex.value = 0
  }
  ensureChainItemState(activeChainIndex.value)
})

// 方法
const loadApis = async () => {
  try {
    const params: any = { limit: 10000 }  // 设置足够大的limit以加载所有接口
    if (filterMethod.value) {
      params.method = filterMethod.value
    }
    apis.value = await api.getApis(params)
    
    // 加载收藏状态
    const favoriteIds = getFavoriteApiIds()
    apis.value.forEach(api => {
      api.is_favorite = favoriteIds.has(api.id)
    })
    
    // 默认选中第一个接口
    if (apis.value.length > 0 && !selectedApi.value) {
      await selectApi(apis.value[0])
    }
  } catch (error) {
    ElMessage.error('加载接口列表失败')
  }
}

const loadEnvironments = async () => {
  try {
    let envs = await api.getEnvironments()
    
    // 从 localStorage 读取保存的顺序
    const savedOrder = localStorage.getItem('env_order')
    if (savedOrder) {
      try {
        const orderIds = JSON.parse(savedOrder) as number[]
        // 根据保存的顺序重新排列
        const orderedEnvs: Environment[] = []
        orderIds.forEach(id => {
          const env = envs.find(e => e.id === id)
          if (env) orderedEnvs.push(env)
        })
        // 添加新增的环境（不在保存的顺序中的）
        envs.forEach(env => {
          if (!orderIds.includes(env.id)) {
            orderedEnvs.push(env)
          }
        })
        envs = orderedEnvs
      } catch (e) {
        console.error('解析环境顺序失败:', e)
      }
    }
    
    environments.value = envs
    if (environments.value.length > 0 && !selectedEnvironment.value) {
      selectedEnvironment.value = environments.value[0].id
    }
  } catch (error) {
    ElMessage.error('加载环境列表失败')
  }
}

const loadTestData = async (apiId: number) => {
  try {
    testDataList.value = await api.getTestDataList(apiId)
    // 如果有测试数据，自动选择第一条并填充
    if (testDataList.value.length > 0) {
      selectedTestData.value = testDataList.value[0].id
      await handleTestDataChange(testDataList.value[0].id)
    }
  } catch (error) {
    ElMessage.error('加载测试数据失败')
  }
}

const selectApi = (apiItem: API) => {
  // 无论什么模式，点击接口都显示详情
  selectedApi.value = apiItem
  selectedTestData.value = 0
  executionResult.value = null
  queryParamsText.value = ''
  pathParamsText.value = ''
  headersText.value = ''
  formDataText.value = ''
  formDataFields.value = []
  bodyText.value = ''
  assertions.value = [createDefaultAssertion()]  // 重置为默认断言
  loadTestData(apiItem.id)
  
  // 如果不在串联模式，切换回单接口测试模式
  if (testMode.value !== 'single') {
    testMode.value = 'single'
  }
}

const switchToChainMode = () => {
  testMode.value = 'chain'
  // 如果没有环境，默认选择第一个
  if (!chainEnvironment.value && environments.value.length > 0) {
    chainEnvironment.value = environments.value[0].id
  }
}

const handleSwaggerFileChange = (file: UploadFile) => {
  swaggerFile.value = file.raw || null
}

const handleMarkdownFileChange = (file: UploadFile) => {
  markdownFile.value = file.raw || null
}

const handleSwaggerUpload = async () => {
  if (!swaggerFile.value) {
    ElMessage.warning('请选择Swagger文件')
    return
  }

  uploading.value = true
  try {
    const result = await api.uploadSwagger(swaggerFile.value)
    ElMessage.success((result as any).message || 'Swagger文件上传成功')
    showSwaggerDialog.value = false
    swaggerFile.value = null
    await loadApis()
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || 'Swagger上传失败')
  } finally {
    uploading.value = false
  }
}

const handleMarkdownUpload = async () => {
  if (!markdownFile.value) {
    ElMessage.warning('请选择Markdown文件')
    return
  }

  uploading.value = true
  try {
    // TODO: 添加Markdown上传的API调用
    ElMessage.warning('Markdown文档解析功能开发中...')
    showMarkdownDialog.value = false
    markdownFile.value = null
    // await api.uploadMarkdown(markdownFile.value)
    // await loadApis()
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || 'Markdown上传失败')
  } finally {
    uploading.value = false
  }
}

const handleDeleteAll = async () => {
  try {
    await ElMessageBox.confirm('确定要清空所有接口吗？', '警告', {
      type: 'warning'
    })
    await api.deleteAllApis()
    ElMessage.success('清空成功')
    apis.value = []
    selectedApi.value = null
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('清空失败')
    }
  }
}

const handleSyncFromUrl = async () => {
  // 弹出环境选择对话框
  showSyncEnvDialog.value = true
  // 如果有环境且未选择，默认选择第一个
  if (environments.value.length > 0 && !syncEnvId.value) {
    syncEnvId.value = environments.value[0].id
  }
}

const handleConfirmSync = async () => {
  if (!syncEnvId.value) {
    ElMessage.warning('请选择同步环境')
    return
  }
  
  const env = environments.value.find(e => e.id === syncEnvId.value)
  if (!env) {
    ElMessage.error('环境不存在')
    return
  }
  
  const fullUrl = env.base_url + syncSwaggerPath.value
  
  try {
    syncing.value = true
    showSyncEnvDialog.value = false
    
    const result = await api.syncSwaggerFromUrl(fullUrl)
    ElMessage.success(result.message)
    await loadApis()
    selectedApi.value = null
  } catch (error: any) {
    ElMessage.error('同步失败: ' + (error.response?.data?.detail || error.message || '未知错误'))
  } finally {
    syncing.value = false
  }
}

// 全局前置操作 - 添加提取规则
const addGlobalExtraction = () => {
  const newKey = `var${Object.keys(globalPreRequest.value.extractions).length + 1}`
  globalPreRequest.value.extractions[newKey] = '$.data.'
}

// 全局前置操作 - 移除提取规则
const removeGlobalExtraction = (varName: string) => {
  delete globalPreRequest.value.extractions[varName]
}

// 全局前置操作 - 处理提取规则变量名修改
const handleGlobalExtractionNameChange = (index: number, newName: string) => {
  const oldKeys = Object.keys(globalPreRequest.value.extractions)
  if (index >= oldKeys.length) return
  
  const oldKey = oldKeys[index]
  if (oldKey === newName) return
  
  const value = globalPreRequest.value.extractions[oldKey]
  const newExtractions: any = {}
  
  oldKeys.forEach((key, i) => {
    if (i === index) {
      if (newName && newName.trim()) {
        newExtractions[newName] = value
      }
    } else {
      newExtractions[key] = globalPreRequest.value.extractions[key]
    }
  })
  
  globalPreRequest.value.extractions = newExtractions
}

// 全局前置操作 - 添加 Header
const addGlobalHeader = () => {
  globalPreRequest.value.headers.push({ key: '', value: '' })
}

// 全局前置操作 - 移除 Header
const removeGlobalHeader = (index: number) => {
  globalPreRequest.value.headers.splice(index, 1)
}

// 全局前置操作 - 添加手动 Header
const addManualHeader = () => {
  globalManualHeaders.value.push({ key: '', value: '' })
}

// 全局前置操作 - 移除手动 Header
const removeManualHeader = (index: number) => {
  globalManualHeaders.value.splice(index, 1)
}

// 全局前置操作 - 当选择API变化时
const handleGlobalPreApiChange = async () => {
  // 清空之前的数据
  globalPreRequest.value.test_data_id = null
  globalPreTestDataList.value = []
  globalPreRequestResult.value = null
  
  // 清空请求参数
  globalPreRequest.value.queryParams = ''
  globalPreRequest.value.pathParams = ''
  globalPreRequest.value.requestHeaders = ''
  globalPreRequest.value.requestBody = ''
  
  if (!globalPreRequest.value.api_id) return
  
  try {
    // 加载该接口的测试数据列表
    const result = await api.getTestDataList(globalPreRequest.value.api_id)
    globalPreTestDataList.value = result
    
    // 自动选择第一条测试数据并填充参数
    if (result.length > 0) {
      globalPreRequest.value.test_data_id = result[0].id
      fillGlobalPreRequestParams(result[0])
    } else {
      ElMessage.warning('该接口暂无测试数据，请先在接口详情中生成测试数据')
    }
  } catch (error: any) {
    console.error('加载测试数据失败:', error)
    ElMessage.error('加载测试数据失败: ' + (error.message || '未知错误'))
  }
}

// 全局前置操作 - 当选择测试数据变化时
const handleGlobalPreTestDataChange = () => {
  if (!globalPreRequest.value.test_data_id) return
  
  const testData = globalPreTestDataList.value.find(
    td => td.id === globalPreRequest.value.test_data_id
  )
  if (testData) {
    fillGlobalPreRequestParams(testData)
  }
}

// 全局前置操作 - 填充请求参数
const fillGlobalPreRequestParams = (testData: TestData) => {
  // 填充 Header
  if (testData.headers && Object.keys(testData.headers).length > 0) {
    globalPreRequest.value.requestHeaders = JSON.stringify(testData.headers, null, 2)
  } else {
    globalPreRequest.value.requestHeaders = ''
  }
  
  // 填充 Query
  if (testData.query_params && Object.keys(testData.query_params).length > 0) {
    globalPreRequest.value.queryParams = JSON.stringify(testData.query_params, null, 2)
  } else {
    globalPreRequest.value.queryParams = ''
  }
  
  // 填充 Body
  if (testData.body) {
    if (typeof testData.body === 'string') {
      globalPreRequest.value.requestBody = testData.body
    } else {
      globalPreRequest.value.requestBody = JSON.stringify(testData.body, null, 2)
    }
  } else {
    globalPreRequest.value.requestBody = ''
  }
  
  // 填充 Path
  if (testData.path_params && Object.keys(testData.path_params).length > 0) {
    globalPreRequest.value.pathParams = JSON.stringify(testData.path_params, null, 2)
  } else {
    globalPreRequest.value.pathParams = ''
  }
}

// 全局前置操作 - 打开对话框并加载保存的配置
const handleOpenGlobalPreRequest = async () => {
  globalPreRequestResult.value = null // 清空上次的执行结果
  globalPreRequestMode.value = 'api' // 确保默认选中接口获取键值对标签页
  await loadGlobalPreRequestConfig()
  showGlobalPreRequestDialog.value = true
}

// 全局前置操作 - 保存配置（带提示）
const handleSaveGlobalPreConfig = () => {
  saveGlobalPreRequestConfig()
  ElMessage.success('已保存本次接口配置')
}

// 全局前置操作 - 保存配置到 localStorage
const saveGlobalPreRequestConfig = () => {
  const config = {
    api_id: globalPreRequest.value.api_id,
    environment_id: globalPreRequest.value.environment_id,
    test_data_id: globalPreRequest.value.test_data_id,
    extractions: globalPreRequest.value.extractions,
    headers: globalPreRequest.value.headers,
    manualHeaders: globalManualHeaders.value,
    mode: globalPreRequestMode.value,
    queryParams: globalPreRequest.value.queryParams,
    pathParams: globalPreRequest.value.pathParams,
    requestHeaders: globalPreRequest.value.requestHeaders,
    requestBody: globalPreRequest.value.requestBody
  }
  localStorage.setItem('globalPreRequestConfig', JSON.stringify(config))
}

// 全局前置操作 - 从 localStorage 加载配置
const loadGlobalPreRequestConfig = async () => {
  try {
    const saved = localStorage.getItem('globalPreRequestConfig')
    if (saved) {
      const config = JSON.parse(saved)
      
      // 恢复接口模式的配置
      if (config.api_id !== undefined) {
        globalPreRequest.value.api_id = config.api_id
      }
      if (config.environment_id !== undefined) {
        globalPreRequest.value.environment_id = config.environment_id
      }
      if (config.test_data_id !== undefined) {
        globalPreRequest.value.test_data_id = config.test_data_id
      }
      if (config.extractions) {
        globalPreRequest.value.extractions = config.extractions
      }
      if (config.headers && Array.isArray(config.headers)) {
        globalPreRequest.value.headers = config.headers
      }
      if (config.queryParams !== undefined) {
        globalPreRequest.value.queryParams = config.queryParams
      }
      if (config.pathParams !== undefined) {
        globalPreRequest.value.pathParams = config.pathParams
      }
      if (config.requestHeaders !== undefined) {
        globalPreRequest.value.requestHeaders = config.requestHeaders
      }
      if (config.requestBody !== undefined) {
        globalPreRequest.value.requestBody = config.requestBody
      }
      
      // 恢复手动模式的配置
      if (config.manualHeaders && Array.isArray(config.manualHeaders)) {
        globalManualHeaders.value = config.manualHeaders
      }
      
      // 恢复模式选择
      if (config.mode) {
        globalPreRequestMode.value = config.mode
      }
    }
    
    // 如果有选中的接口，加载其测试数据列表并填充默认数据
    if (globalPreRequest.value.api_id) {
      try {
        const result = await api.getTestDataList(globalPreRequest.value.api_id)
        globalPreTestDataList.value = result
        
        // 如果有保存的 test_data_id 则优先使用，否则自动选择第一条
        if (result.length > 0) {
          const matched = result.find(td => td.id === globalPreRequest.value.test_data_id)
          const target = matched || result[0]
          globalPreRequest.value.test_data_id = target.id
          fillGlobalPreRequestParams(target)
        }
      } catch (error) {
        console.error('加载测试数据失败:', error)
      }
    }
  } catch (e) {
    console.warn('加载全局前置操作配置失败:', e)
  }
}

// 全局前置操作 - 执行前置接口（仅执行，不同步）
const handleExecutePreRequestApi = async () => {
  if (!globalPreRequest.value.api_id) {
    ElMessage.warning('请选择接口')
    return
  }
  
  if (!globalPreRequest.value.environment_id) {
    ElMessage.warning('请选择执行环境')
    return
  }
  
  try {
    executingGlobalPre.value = true
    
    // 构建请求数据
    const requestData: any = {
      environment_id: globalPreRequest.value.environment_id
    }
    
    // 解析请求参数
    if (globalPreRequest.value.queryParams && globalPreRequest.value.queryParams.trim()) {
      try {
        requestData.query_params = JSON.parse(globalPreRequest.value.queryParams)
      } catch (e) {
        ElMessage.warning('Query 参数格式不正确，请检查 JSON 格式')
        return
      }
    }
    
    if (globalPreRequest.value.pathParams && globalPreRequest.value.pathParams.trim()) {
      try {
        requestData.path_params = JSON.parse(globalPreRequest.value.pathParams)
      } catch (e) {
        ElMessage.warning('Path 参数格式不正确，请检查 JSON 格式')
        return
      }
    }
    
    if (globalPreRequest.value.requestHeaders && globalPreRequest.value.requestHeaders.trim()) {
      try {
        requestData.headers = JSON.parse(globalPreRequest.value.requestHeaders)
      } catch (e) {
        ElMessage.warning('Header 格式不正确，请检查 JSON 格式')
        return
      }
    }
    
    if (globalPreRequest.value.requestBody && globalPreRequest.value.requestBody.trim()) {
      try {
        requestData.body = JSON.parse(globalPreRequest.value.requestBody)
      } catch (e) {
        ElMessage.warning('Body 格式不正确，请检查 JSON 格式')
        return
      }
    }
    
    // 执行接口
    const result = await api.executeApi(globalPreRequest.value.api_id, requestData)
    
    if (!result || !result.response_body) {
      ElMessage.error('接口执行失败或无响应')
      return
    }
    
    // 保存执行结果
    globalPreRequestResult.value = result
    ElMessage.success('接口执行成功')
    
  } catch (error: any) {
    ElMessage.error('执行失败: ' + (error.response?.data?.detail || error.message || '未知错误'))
    globalPreRequestResult.value = null
  } finally {
    executingGlobalPre.value = false
  }
}

// 全局前置操作 - 同步提取的变量到所有测试数据
const handleSyncExtractedVariables = async () => {
  if (!globalPreRequestResult.value) {
    ElMessage.warning('请先执行接口')
    return
  }
  
  if (globalPreRequest.value.headers.length === 0) {
    ElMessage.warning('请至少添加一个要同步的键值对')
    return
  }
  
  // 检查是否有空的key
  const hasEmptyKey = globalPreRequest.value.headers.some(h => !h.key || !h.key.trim())
  if (hasEmptyKey) {
    ElMessage.warning('请填写完整的键名')
    return
  }
  
  try {
    // 提取变量
    const extractedVars: Record<string, any> = {}
    let responseData: any
    
    try {
      responseData = typeof globalPreRequestResult.value.response_body === 'string' 
        ? JSON.parse(globalPreRequestResult.value.response_body) 
        : globalPreRequestResult.value.response_body
    } catch (e) {
      ElMessage.error('响应数据不是有效的 JSON')
      return
    }
    
    // 使用简单的 JSONPath 提取
    for (const [varName, jsonPath] of Object.entries(globalPreRequest.value.extractions)) {
      try {
        const value = extractValueByPath(responseData, jsonPath)
        if (value !== undefined) {
          extractedVars[varName] = value
        }
      } catch (e) {
        console.warn(`提取变量 ${varName} 失败:`, e)
      }
    }
    
    if (Object.keys(extractedVars).length === 0) {
      ElMessage.warning('未能提取到任何变量，请检查 JSONPath 配置')
      return
    }
    
    // 替换 Header 中的变量占位符，将数组转换为对象
    const finalHeaders: Record<string, string> = {}
    for (const header of globalPreRequest.value.headers) {
      if (header.key && header.key.trim()) {
        let replacedValue = header.value
        for (const [varName, varValue] of Object.entries(extractedVars)) {
          replacedValue = replacedValue.replace(new RegExp(`\\{\\{${varName}\\}\\}`, 'g'), String(varValue))
        }
        finalHeaders[header.key] = replacedValue
      }
    }
    
    // 同步到所有测试数据
    await syncHeadersToAllTestData(finalHeaders)
    
    // 保存配置
    saveGlobalPreRequestConfig()
    
    ElMessage.success(`成功提取 ${Object.keys(extractedVars).length} 个变量并同步到所有测试数据`)
    showGlobalPreRequestDialog.value = false
    
  } catch (error: any) {
    ElMessage.error('操作失败: ' + (error.response?.data?.detail || error.message || '未知错误'))
  }
}

// 全局前置操作 - 执行接口并同步（旧版本，保留以防其他地方使用）
const handleExecuteGlobalPreRequest = async () => {
  if (!globalPreRequest.value.api_id) {
    ElMessage.warning('请选择登录接口')
    return
  }
  
  if (!selectedEnvironment.value) {
    ElMessage.warning('请先选择环境')
    return
  }
  
  if (globalPreRequest.value.headers.length === 0) {
    ElMessage.warning('请至少添加一个要同步的键值对')
    return
  }
  
  // 检查是否有空的key
  const hasEmptyKey = globalPreRequest.value.headers.some(h => !h.key || !h.key.trim())
  if (hasEmptyKey) {
    ElMessage.warning('请填写完整的键名')
    return
  }
  
  try {
    executingGlobalPre.value = true
    
    // 执行前置接口
    const requestData: any = {
      environment_id: selectedEnvironment.value,
      test_data_id: globalPreRequest.value.test_data_id
    }
    
    const result = await api.executeApi(globalPreRequest.value.api_id, requestData)
    
    if (!result || !result.response_body) {
      ElMessage.error('前置接口执行失败或无响应')
      return
    }
    
    // 提取变量
    const extractedVars: Record<string, any> = {}
    let responseData: any
    
    try {
      responseData = typeof result.response_body === 'string' 
        ? JSON.parse(result.response_body) 
        : result.response_body
    } catch (e) {
      ElMessage.error('响应数据不是有效的 JSON')
      return
    }
    
    // 使用简单的 JSONPath 提取
    for (const [varName, jsonPath] of Object.entries(globalPreRequest.value.extractions)) {
      try {
        const value = extractValueByPath(responseData, jsonPath)
        if (value !== undefined) {
          extractedVars[varName] = value
        }
      } catch (e) {
        console.warn(`提取变量 ${varName} 失败:`, e)
      }
    }
    
    if (Object.keys(extractedVars).length === 0) {
      ElMessage.warning('未能提取到任何变量，请检查 JSONPath 配置')
      return
    }
    
    // 替换 Header 中的变量占位符，将数组转换为对象
    const finalHeaders: Record<string, string> = {}
    for (const header of globalPreRequest.value.headers) {
      if (header.key && header.key.trim()) {
        let replacedValue = header.value
        for (const [varName, varValue] of Object.entries(extractedVars)) {
          replacedValue = replacedValue.replace(new RegExp(`\\{\\{${varName}\\}\\}`, 'g'), String(varValue))
        }
        finalHeaders[header.key] = replacedValue
      }
    }
    
    // 同步到所有测试数据
    await syncHeadersToAllTestData(finalHeaders)
    
    // 保存配置
    saveGlobalPreRequestConfig()
    
    ElMessage.success(`成功提取 ${Object.keys(extractedVars).length} 个变量并同步到所有测试数据`)
    showGlobalPreRequestDialog.value = false
    
  } catch (error: any) {
    ElMessage.error('操作失败: ' + (error.response?.data?.detail || error.message || '未知错误'))
  } finally {
    executingGlobalPre.value = false
  }
}

// 全局前置操作 - 手动同步 Headers
const handleSyncManualHeaders = async () => {
  if (globalManualHeaders.value.length === 0) {
    ElMessage.warning('请至少添加一个 Header')
    return
  }
  
  // 检查是否有空的key
  const hasEmptyKey = globalManualHeaders.value.some(h => !h.key || !h.key.trim())
  if (hasEmptyKey) {
    ElMessage.warning('请填写完整的键名')
    return
  }
  
  // 将数组转换为对象
  const headersObj: Record<string, string> = {}
  for (const header of globalManualHeaders.value) {
    if (header.key && header.key.trim()) {
      headersObj[header.key] = header.value
    }
  }
  
  try {
    await syncHeadersToAllTestData(headersObj)
    
    // 保存配置
    saveGlobalPreRequestConfig()
    
    ElMessage.success(`成功同步 ${Object.keys(headersObj).length} 个 Header 到所有测试数据`)
    showGlobalPreRequestDialog.value = false
  } catch (error: any) {
    ElMessage.error('同步失败: ' + (error.message || '未知错误'))
  }
}

// 辅助函数 - 简单的 JSONPath 提取
const extractValueByPath = (obj: any, path: string): any => {
  // 移除开头的 $. 和 $
  let cleanPath = path.trim()
  if (cleanPath.startsWith('$.')) {
    cleanPath = cleanPath.substring(2)
  } else if (cleanPath.startsWith('$')) {
    cleanPath = cleanPath.substring(1)
  }
  
  if (!cleanPath) return obj
  
  const parts = cleanPath.split('.')
  let current = obj
  
  for (const part of parts) {
    if (current === null || current === undefined) {
      return undefined
    }
    
    // 处理数组索引，如 items[0]
    const arrayMatch = part.match(/^(\w+)\[(\d+)\]$/)
    if (arrayMatch) {
      const [, key, index] = arrayMatch
      current = current[key]?.[parseInt(index)]
    } else {
      current = current[part]
    }
  }
  
  return current
}

// 辅助函数 - 同步 Headers 到所有测试数据
const syncHeadersToAllTestData = async (headers: Record<string, string>) => {
  // 获取所有测试数据
  const allTestData: TestData[] = []
  for (const apiItem of apis.value) {
    try {
      const testDataList = await api.getTestDataList(apiItem.id)
      allTestData.push(...testDataList)
    } catch (e) {
      console.warn(`获取接口 ${apiItem.id} 的测试数据失败`, e)
    }
  }
  
  if (allTestData.length === 0) {
    ElMessage.warning('没有找到任何测试数据')
    return
  }
  
  // 更新每个测试数据的 Headers
  let successCount = 0
  let failCount = 0
  
  for (const testData of allTestData) {
    try {
      // 合并现有 Headers 和新 Headers
      const existingHeaders = testData.headers || {}
      const mergedHeaders = { ...existingHeaders, ...headers }
      
      // 更新测试数据
      await api.updateTestData(testData.id, {
        ...testData,
        headers: mergedHeaders
      })
      
      successCount++
    } catch (e) {
      console.error(`更新测试数据 ${testData.id} 失败`, e)
      failCount++
    }
  }
  
  console.log(`同步完成: 成功 ${successCount} 个, 失败 ${failCount} 个`)
  
  // 如果当前选中的接口有测试数据，重新加载
  if (selectedApi.value) {
    await loadTestData(selectedApi.value.id)
    if (selectedTestData.value) {
      await handleTestDataChange(selectedTestData.value)
    }
  }
}

const handleExecute = async () => {
  if (!selectedApi.value) return
  if (!selectedEnvironment.value) {
    ElMessage.warning('请选择环境')
    return
  }

  executing.value = true
  try {
    const requestData: any = {
      environment_id: selectedEnvironment.value,
      test_data_id: selectedTestData.value === 0 ? null : selectedTestData.value
    }

    // 解析JSON参数
    if (queryParamsText.value.trim()) {
      requestData.query_params = JSON.parse(queryParamsText.value)
    }
    if (pathParamsText.value.trim()) {
      requestData.path_params = JSON.parse(pathParamsText.value)
    }
    if (headersText.value.trim()) {
      requestData.headers = JSON.parse(headersText.value)
    }
    // 从 formDataFields 获取数据
    const formDataObj = getFormDataObject()
    if (formDataObj) {
      requestData.form_data = formDataObj
    }
    if (bodyText.value.trim()) {
      try {
      requestData.body = JSON.parse(bodyText.value)
      } catch (e) {
        console.warn('解析Body失败，按原文本发送', e)
        requestData.body = bodyText.value
      }
    }

    executionResult.value = await api.executeApi(selectedApi.value.id, requestData)
    
    // 运行断言
    if (assertions.value.length > 0) {
      runAssertions(executionResult.value)
      const summary = assertionSummary.value
      if (summary.failed > 0) {
        ElMessage.warning(`Success, but ${summary.failed}/${summary.total} assertion(s) failed`)
      } else {
        ElMessage.success(`Success, all ${summary.total} assertion(s) passed`)
      }
    } else {
      ElMessage.success('执行成功')
    }
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '执行失败')
  } finally {
    executing.value = false
  }
}

const handleBatchExecute = async () => {
  if (!selectedEnvironment.value) {
    ElMessage.warning('请选择环境')
    return
  }

  if (apis.value.length === 0) {
    ElMessage.warning('没有可执行的接口')
    return
  }

  try {
    await ElMessageBox.confirm(`确定要批量执行 ${apis.value.length} 个接口吗？`, '提示', {
      type: 'info'
    })

    batchExecuting.value = true
    const result = await api.batchExecute({
      environment_id: selectedEnvironment.value
    })
    
    ElMessage.success(result.message)
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error(error.response?.data?.detail || '批量执行失败')
    }
  } finally {
    batchExecuting.value = false
  }
}

const handleSaveTestData = async () => {
  if (!selectedApi.value) return
  if (!testDataForm.value.name.trim()) {
    ElMessage.warning('请输入数据名称')
    return
  }

  try {
    const data: any = {
      api_id: selectedApi.value.id,
      name: testDataForm.value.name
    }

    if (testDataForm.value.query_params.trim()) {
      data.query_params = JSON.parse(testDataForm.value.query_params)
    }
    if (testDataForm.value.path_params.trim()) {
      data.path_params = JSON.parse(testDataForm.value.path_params)
    }
    if (testDataForm.value.headers.trim()) {
      data.headers = JSON.parse(testDataForm.value.headers)
    }
    if (testDataForm.value.body.trim()) {
      data.body = JSON.parse(testDataForm.value.body)
    }

    // 添加前置接口配置
    if (testDataForm.value.pre_request_api_id) {
      data.pre_request_api_id = testDataForm.value.pre_request_api_id
      if (testDataForm.value.pre_request_test_data_id) {
        data.pre_request_test_data_id = testDataForm.value.pre_request_test_data_id
      }
      if (Object.keys(testDataForm.value.variable_extractions).length > 0) {
        data.variable_extractions = testDataForm.value.variable_extractions
      }
    }

    await api.createTestData(data)
    ElMessage.success('保存成功')
    showTestDataDialog.value = false
    testDataForm.value = {
      name: '',
      query_params: '',
      path_params: '',
      headers: '',
      body: '',
      variable_extractions: {}
    }
    await loadTestData(selectedApi.value.id)
  } catch (error: any) {
    ElMessage.error((error as any).response?.data?.detail || '保存失败')
  }
}

// 获取指定 API 的测试数据列表
const getTestDataByApiId = (apiId: number) => {
  return testDataList.value.filter((td: any) => td.api_id === apiId)
}

// 添加变量提取规则
const addVariableExtraction = () => {
  const newKey = `var${Object.keys(testDataForm.value.variable_extractions as any).length + 1}`
  (testDataForm.value.variable_extractions as any)[newKey] = '$.data.'
}

// 移除变量提取规则
const removeVariableExtraction = (varName: string) => {
  delete (testDataForm.value.variable_extractions as any)[varName]
}

// 处理变量名修改
const handleVariableNameChange = (index: number, newName: string) => {
  const oldKeys = Object.keys(testDataForm.value.variable_extractions as any)
  if (index >= oldKeys.length) return
  
  const oldKey = oldKeys[index]
  if (oldKey === newName) return
  
  const value = (testDataForm.value.variable_extractions as any)[oldKey]
  const newExtractions: any = {}
  
  oldKeys.forEach((key, i) => {
    if (i === index) {
      if (newName && newName.trim()) {
        newExtractions[newName] = value
      }
    } else {
      newExtractions[key] = (testDataForm.value.variable_extractions as any)[key]
    }
  })
  
  testDataForm.value.variable_extractions = newExtractions
}

const handleDeleteTestData = async (id: number) => {
  try {
    await ElMessageBox.confirm('确定要删除这条测试数据吗？', '提示', {
      type: 'warning'
    })
    await api.deleteTestData(id)
    ElMessage.success('删除成功')
    if (selectedApi.value) {
      await loadTestData(selectedApi.value.id)
    }
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败')
    }
  }
}

// Form Data 相关方法
const addFormDataField = () => {
  formDataFields.value.push({
    key: '',
    value: '',
    type: 'text',
    description: '',
    fileList: []
  })
}

const removeFormDataField = (index: number) => {
  formDataFields.value.splice(index, 1)
}

const handleFormTypeChange = (row: any) => {
  if (row.type === 'file') {
    row.value = ''
    row.file = undefined
    row.fileName = ''
    row.fileList = []
  }
}

const handleFormFileChange = (row: any, file: UploadFile) => {
  row.file = file.raw
  row.fileName = file.name
  row.fileList = [file]
}

const handleFormFileRemove = (row: any) => {
  row.file = undefined
  row.fileName = ''
  row.fileList = []
}

// 将 formDataFields 转换为普通对象（用于保存）
const getFormDataObject = () => {
  const formData: any = {}
  formDataFields.value.forEach(field => {
    if (field.key) {
      if (field.type === 'file') {
        formData[field.key] = field.fileName || '<file upload>'
      } else {
        formData[field.key] = field.value
      }
    }
  })
  return Object.keys(formData).length > 0 ? formData : null
}

const handleGenerateTestData = async () => {
  if (!selectedApi.value) return
  
  // 限制最多3个测试数据（默认 + 2个生成的）
  if (testDataList.value.length >= 3) {
    ElMessage.warning('最多只能生成3个测试数据（1个默认 + 2个生成）')
    return
  }
  
  try {
    await api.generateTestData(selectedApi.value.id)
    ElMessage.success('生成测试数据成功')
    
    // 重新加载测试数据列表
    await loadTestData(selectedApi.value.id)
    
    // 自动选中最新生成的测试数据（列表中的最后一个）
    if (testDataList.value.length > 0) {
      const latestTestData = testDataList.value[testDataList.value.length - 1]
      selectedTestData.value = latestTestData.id
      
      // 自动加载并填充到参数区
      await handleTestDataChange(latestTestData.id)
    }
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '生成测试数据失败')
  }
}

// 导出当前接口相关数据
const handleExportApiData = () => {
  if (!selectedApi.value) {
    ElMessage.warning('请先选择接口')
    return
  }

  const filenamePath = selectedApi.value.path.replace(/\//g, '-').replace(/^-+/, '')
  const desc = selectedApi.value.summary || selectedApi.value.operation_id || 'api'
  const fileName = `${filenamePath}-${desc}.json`

  const payload = {
    api: selectedApi.value,
    testDataList: testDataList.value,
    environments: environments.value,
    currentParams: {
      query: queryParamsText.value,
      path: pathParamsText.value,
      headers: headersText.value,
      body: bodyText.value,
      formData: formDataText.value
    }
  }

  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = fileName
  a.click()
  URL.revokeObjectURL(url)
  ElMessage.success(`已导出到文件：${fileName}`)
}

const handleSaveCurrentTestData = () => {
  if (!selectedApi.value) {
    ElMessage.warning('请先选择接口')
    return
  }
  
  // 将当前输入的参数填充到表单中
  testDataForm.value = {
    name: '',
    query_params: queryParamsText.value,
    path_params: pathParamsText.value,
    headers: headersText.value,
    body: bodyText.value,
    variable_extractions: {}
  }
  
  showTestDataDialog.value = true
}

const handleUpdateTestData = async () => {
  if (!selectedApi.value || !selectedTestData.value) {
    ElMessage.warning('请先选择测试数据')
    return
  }

  const parseJsonOrEmpty = (text: string, field: string) => {
    if (!text || !text.trim()) return {}
    try {
      return JSON.parse(text)
    } catch (e) {
      ElMessage.warning(`${field} 参数格式不正确，请检查 JSON 格式`)
      throw e
    }
  }
  
  try {
    const data: any = {
      api_id: selectedApi.value.id
    }
    
    // 解析并更新参数
    data.query_params = parseJsonOrEmpty(queryParamsText.value, 'Query')
    data.path_params = parseJsonOrEmpty(pathParamsText.value, 'Path')
    data.headers = parseJsonOrEmpty(headersText.value, 'Header')
    
    // 从 formDataFields 获取数据
    const formDataObj = getFormDataObject()
    data.form_data = formDataObj || {}
    
    data.body = parseJsonOrEmpty(bodyText.value, 'Body')
    
    // 保存断言配置（清除结果相关字段，只保存配置）
    if (assertions.value.length > 0) {
      data.assertions = assertions.value.map(a => ({
        type: a.type,
        path: a.path,
        operator: a.operator,
        expected: a.expected
      }))
    } else {
      data.assertions = []
    }
    
    // 更新测试数据
    await api.updateTestData(selectedTestData.value, data)
    ElMessage.success('测试数据更新成功')
    
    // 重新加载测试数据列表
    await loadTestData(selectedApi.value.id)
  } catch (error: any) {
    ElMessage.error(error.response?.data?.detail || '更新测试数据失败')
  }
}

const handleAddEnvironment = () => {
  editingEnvId.value = null
  envForm.value = {
    name: '',
    base_url: '',
    description: '',
    headers: ''
  }
  showEnvDialog.value = true
}

const handleEditEnvironment = (env: Environment) => {
  editingEnvId.value = env.id
  envForm.value = {
    name: env.name,
    base_url: env.base_url,
    description: env.description || '',
    headers: env.headers ? JSON.stringify(env.headers, null, 2) : ''
  }
  showEnvDialog.value = true
}

const handleEditEnvironmentById = (envId: number) => {
  const env = environments.value.find(e => e.id === envId)
  if (env) {
    handleEditEnvironment(env)
  }
}

const moveEnvironment = (index: number, direction: number) => {
  const newIndex = index + direction
  if (newIndex < 0 || newIndex >= environments.value.length) return
  
  // 交换位置
  const temp = environments.value[index]
  environments.value[index] = environments.value[newIndex]
  environments.value[newIndex] = temp
  
  // 保存顺序到 localStorage
  const orderIds = environments.value.map(env => env.id)
  localStorage.setItem('env_order', JSON.stringify(orderIds))
  
  ElMessage.success(`✅ 已${direction > 0 ? '下' : '上'}移并保存: ${temp.name}`)
}

const handleDeleteEnvironment = async (envId: number) => {
  try {
    await ElMessageBox.confirm('确定要删除这个环境配置吗？', '删除环境配置', {
      type: 'warning',
      confirmButtonText: '确定',
      cancelButtonText: '取消'
    })
    
    await api.deleteEnvironment(envId)
    ElMessage.success('删除环境配置成功')
    
    // 如果删除的是当前选中的环境，清空选择
    if (selectedEnvironment.value === envId) {
      selectedEnvironment.value = undefined
    }
    
    // 从 localStorage 中移除已删除的环境ID
    const savedOrder = localStorage.getItem('env_order')
    if (savedOrder) {
      try {
        const orderIds = JSON.parse(savedOrder) as number[]
        const newOrderIds = orderIds.filter(id => id !== envId)
        localStorage.setItem('env_order', JSON.stringify(newOrderIds))
      } catch (e) {
        console.error('更新环境顺序失败:', e)
      }
    }
    
    await loadEnvironments()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error(error.response?.data?.detail || '删除环境配置失败')
    }
  }
}

const handleSaveEnvironment = async () => {
  if (!envForm.value.name.trim()) {
    ElMessage.warning('请输入环境名称')
    return
  }
  if (!envForm.value.base_url.trim()) {
    ElMessage.warning('请输入基础URL')
    return
  }

  try {
    const data: any = {
      name: envForm.value.name,
      base_url: envForm.value.base_url,
      description: envForm.value.description || ''
    }

    // 解析请求头JSON
    if (envForm.value.headers.trim()) {
      try {
        data.headers = JSON.parse(envForm.value.headers)
      } catch (e) {
        ElMessage.error('请求头JSON格式错误')
        return
      }
    }

    if (editingEnvId.value) {
      // 编辑模式
      await api.updateEnvironment(editingEnvId.value, data)
      ElMessage.success('修改环境配置成功')
    } else {
      // 添加模式
      await api.createEnvironment(data)
      ElMessage.success('添加环境配置成功')
    }
    
    showEnvDialog.value = false
    editingEnvId.value = null
    envForm.value = {
      name: '',
      base_url: '',
      description: '',
      headers: ''
    }
    await loadEnvironments()
  } catch (error: any) {
    const action = editingEnvId.value ? '修改' : '添加'
    ElMessage.error(error.response?.data?.detail || `${action}环境配置失败`)
  }
}

// 搜索和过滤由 filteredApis 计算属性自动处理，无需手动触发

const getMethodType = (method: string): 'success' | 'warning' | 'danger' | 'info' => {
  const map: Record<string, 'success' | 'warning' | 'danger' | 'info'> = {
    GET: 'success',
    POST: 'warning',
    PUT: 'info',
    DELETE: 'danger',
    PATCH: 'info'
  }
  return map[method] || 'info'
}

const getStatusType = (status?: number): 'success' | 'warning' | 'danger' | 'info' => {
  if (!status) return 'info'
  if (status >= 200 && status < 300) return 'success'
  if (status >= 300 && status < 400) return 'info'
  if (status >= 400 && status < 500) return 'warning'
  return 'danger'
}

// 断言相关方法
const addAssertion = () => {
  assertions.value.push({
    type: 'status_code',
    operator: 'eq',
    expected: '200'
  })
}

const insertAssertion = (index: number) => {
  assertions.value.splice(index, 0, {
    type: 'status_code',
    operator: 'eq',
    expected: '200'
  })
}

const removeAssertion = (index: number) => {
  assertions.value.splice(index, 1)
  // 如果删除后为空，添加默认的一行状态码
  if (assertions.value.length === 0) {
    assertions.value.push(createDefaultAssertion())
  }
}

// 链接口断言相关方法
const addChainAssertion = (chainIndex: number) => {
  if (!chainItemAssertions.value[chainIndex]) {
    chainItemAssertions.value[chainIndex] = [createDefaultAssertion()]
  }
  chainItemAssertions.value[chainIndex].push(createDefaultAssertion())
}

const insertChainAssertion = (chainIndex: number, assertionIndex: number) => {
  if (!chainItemAssertions.value[chainIndex]) {
    chainItemAssertions.value[chainIndex] = [createDefaultAssertion()]
  }
  chainItemAssertions.value[chainIndex].splice(assertionIndex, 0, createDefaultAssertion())
}

const removeChainAssertion = (chainIndex: number, assertionIndex: number) => {
  if (chainItemAssertions.value[chainIndex]) {
    chainItemAssertions.value[chainIndex].splice(assertionIndex, 1)
    // 如果删除后为空，添加默认的一行状态码
    if (chainItemAssertions.value[chainIndex].length === 0) {
      chainItemAssertions.value[chainIndex].push(createDefaultAssertion())
    }
  }
}

const getExpectedPlaceholder = (type: string) => {
  switch (type) {
    case 'status_code': return '如: 200'
    case 'json_path': return '期望值'
    case 'response_time': return '毫秒, 如: 1000'
    case 'contains': return '包含的文本'
    default: return '期望值'
  }
}

// 通过 JSONPath 获取值（支持以 $ 或 $. 开头，支持数组下标 data.list[0].name）
const getValueByPath = (obj: any, path: string): any => {
  if (!obj || !path) return undefined
  const normalizedPath = path.replace(/^\$\./, '').replace(/^\$/, '')
  const parts = normalizedPath.split('.')
  let value = obj
  for (const part of parts) {
    if (value === undefined || value === null) return undefined
    // 处理 array[index] 访问
    const arrMatch = part.match(/^(\w+)\[(\d+)\]$/)
    if (arrMatch) {
      const key = arrMatch[1]
      const idx = Number(arrMatch[2])
      if (!Array.isArray(value[key]) || idx >= value[key].length) return undefined
      value = value[key][idx]
      continue
    }
    value = value[part]
  }
  return value
}

// 执行断言
const runAssertions = (result: any) => {
  assertions.value.forEach(assertion => {
    let actualValue: any
    let passed = false
    
    switch (assertion.type) {
      case 'status_code':
        actualValue = result.response_status
        break
      case 'json_path':
        actualValue = getValueByPath(result.response_body, assertion.path || '')
        break
      case 'response_time':
        actualValue = result.response_time
        break
      case 'contains':
        actualValue = JSON.stringify(result.response_body || '')
        break
    }
    
    const expected = assertion.expected
    const actualStr = String(actualValue ?? '')
    
    switch (assertion.operator) {
      case 'eq':
        passed = actualStr === expected || actualValue == expected
        break
      case 'ne':
        passed = actualStr !== expected && actualValue != expected
        break
      case 'gt':
        passed = Number(actualValue) > Number(expected)
        break
      case 'lt':
        passed = Number(actualValue) < Number(expected)
        break
      case 'contains':
        passed = actualStr.includes(expected)
        break
      case 'not_contains':
        passed = !actualStr.includes(expected)
        break
    }
    
    assertion.result = passed
    assertion.actualValue = actualStr
  })
}

// 执行链接口断言
const runChainAssertions = (chainIndex: number, result: any) => {
  const assertions = chainItemAssertions.value[chainIndex]
  if (!assertions || assertions.length === 0) return { total: 0, passed: 0, failed: 0, failures: [] as any[] }
  // 将期望值中支持的占位符（目前仅支持 $.global.xxx）解析成真实值
  const resolveExpected = (expected: string) => {
    if (!expected) return expected
    const globalMatch = expected.match(/^\$\.global\.([A-Za-z0-9_]+)/)
    if (globalMatch) {
      const key = globalMatch[1]
      const val = chainGlobalVarMap.value[key]
      if (val === undefined || val === null) return expected
      return typeof val === 'string' ? val : JSON.stringify(val)
    }
    return expected
  }
  
  assertions.forEach(assertion => {
    let actualValue: any
    let passed = false
    let expectedResolved: string | undefined
    
    switch (assertion.type) {
      case 'status_code':
        actualValue = result.response_status
        break
      case 'json_path':
        actualValue = getValueByPath(result.response_body, assertion.path || '')
        break
      case 'response_time':
        actualValue = result.response_time
        break
      case 'contains':
        actualValue = JSON.stringify(result.response_body || '')
        break
    }
    
    const expected = resolveExpected(assertion.expected)
    expectedResolved = expected
    const actualStr = String(actualValue ?? '')
    
    switch (assertion.operator) {
      case 'eq':
        passed = actualStr === expected || actualValue == expected
        break
      case 'ne':
        passed = actualStr !== expected && actualValue != expected
        break
      case 'gt':
        passed = Number(actualValue) > Number(expected)
        break
      case 'lt':
        passed = Number(actualValue) < Number(expected)
        break
      case 'contains':
        passed = actualStr.includes(expected)
        break
      case 'not_contains':
        passed = !actualStr.includes(expected)
        break
    }
    
    assertion.result = passed
    assertion.actualValue = actualStr
    // 附带预期值，便于展示
    ;(assertion as any).resolvedExpected = expectedResolved
  })
  
  const total = assertions.length
  const passed = assertions.filter(a => a.result === true).length
  const failed = assertions.filter(a => a.result === false).length
  
  const failures = assertions
    .filter(a => a.result === false)
    .map(a => ({
      type: a.type,
      operator: a.operator,
      path: a.path,
      expected: (a as any).resolvedExpected ?? a.expected,
      actual: a.actualValue
    }))
  
  return { total, passed, failed, failures }
}

// 选择测试数据项
const selectTestDataItem = async (tdId: number) => {
  selectedTestData.value = tdId
  await handleTestDataChange(tdId)
}

const handleTestDataChange = async (val: number) => {
  if (!selectedApi.value || !val) return
  
  // 加载选中的测试数据
  try {
    const td: any = await api.getTestData(val)
      queryParamsText.value = td.query_params ? JSON.stringify(td.query_params, null, 2) : ''
      pathParamsText.value = td.path_params ? JSON.stringify(td.path_params, null, 2) : ''
      headersText.value = td.headers ? JSON.stringify(td.headers, null, 2) : ''
    
    // 加载 Form Data 到表格
    if ((td as any).form_data) {
      formDataFields.value = Object.entries((td as any).form_data).map(([key, value]) => ({
        key,
        value: value === '<file upload>' ? '' : String(value),
        type: value === '<file upload>' ? 'file' : 'text',
        description: key === 'file' ? '文件上传' : '',
        fileList: []
      }))
    } else {
      formDataFields.value = []
    }
    
      bodyText.value = td.body ? JSON.stringify(td.body, null, 2) : ''
    
    // 加载断言配置
    if ((td as any).assertions && Array.isArray((td as any).assertions) && (td as any).assertions.length > 0) {
      assertions.value = (td as any).assertions.map((a: any) => ({
        type: a.type || 'status_code',
        path: a.path || '',
        operator: a.operator || 'eq',
        expected: a.expected || '',
        result: undefined,
        actualValue: undefined
      }))
    } else {
      assertions.value = [createDefaultAssertion()]  // 如果没有断言，使用默认的一行状态码
    }
    
    ElMessage.success(`已加载测试数据: ${td.name}`)
    } catch (error) {
      ElMessage.error('加载测试数据失败')
    }
}

// 串联执行相关方法
const selectChainItem = (index: number) => {
  if (index < 0 || index >= chainApis.value.length) return
  activeChainIndex.value = index
  ensureChainItemState(index)
  chainEditorVisible.value = true
}

const addToChain = async (apiItem: API) => {
  // 如果不在串联模式，先切换到串联模式
  if (testMode.value !== 'chain') {
    testMode.value = 'chain'
  }
  
  // 可以重复添加同一个接口（允许在流程中多次调用同一接口）
  const index = chainApis.value.length
  chainApis.value.push({...apiItem})
  activeChainIndex.value = index
  
  // 初始化参数配置
  initChainItemParams(index)
  
  let filled = false

  // 优先使用当前界面已选接口的最新输入（单向拷贝）
  if (selectedApi.value && selectedApi.value.id === apiItem.id) {
    try {
      // 优先使用当前界面显示的断言（可能还未保存到测试数据）
      if (assertions.value && assertions.value.length > 0) {
        // 深拷贝当前界面的断言配置
        chainItemAssertions.value[index] = JSON.parse(JSON.stringify(assertions.value.map(a => ({
          type: a.type,
          path: a.path || '',
          operator: a.operator,
          expected: a.expected || ''
        }))))
      }
      
      // 加载测试数据填充参数（保留已设置的断言）
      const td = await api.getTestData(selectedTestData.value as number)
      fillChainFromTestData(index, td, true) // preserveAssertions = true
      
      filled = true
    } catch (e) {
      // 如果当前测试数据不存在，则退回默认加载
      console.warn('使用当前测试数据填充失败，回退到默认:', e)
    }
  }

  // 回退：若未填充成功，则加载默认测试数据
  if (!filled) {
    try {
      const testDataList = await api.getTestDataList(apiItem.id)
      if (testDataList.length > 0) {
        const td = await api.getTestData(testDataList[0].id)
        fillChainFromTestData(index, td)
      }
    } catch (error) {
      console.error('加载测试数据失败:', error)
      // 不影响添加到执行链的流程
    }
  }
  
  ElMessage.success(`✅ 已添加到执行链: ${apiItem.summary || apiItem.path}`)
}

const removeFromChain = (index: number) => {
  const item = chainApis.value[index]
  chainApis.value.splice(index, 1)
  
  // 移除对应的结果
  if (chainResults.value.length > index) {
    chainResults.value.splice(index, 1)
  }
  
  // 重新组织参数、展开状态、标签页状态和断言（因为索引会变化）
  const newParams: Record<number, {query: string, body: string, headers: string}> = {}
  const newExpanded: Record<number, boolean> = {}
  const newActiveTabs: Record<number, string> = {}
  const newAssertions: Record<number, Assertion[]> = {}
  
  Object.keys(chainItemParams.value).forEach((key) => {
    const idx = parseInt(key)
    if (idx < index) {
      newParams[idx] = chainItemParams.value[idx]
      newExpanded[idx] = expandedChainItems.value[idx]
      if (chainItemActiveTab.value[idx]) {
        newActiveTabs[idx] = chainItemActiveTab.value[idx]
      }
      if (chainItemAssertions.value[idx]) {
        newAssertions[idx] = chainItemAssertions.value[idx]
      }
    } else if (idx > index) {
      newParams[idx - 1] = chainItemParams.value[idx]
      newExpanded[idx - 1] = expandedChainItems.value[idx]
      if (chainItemActiveTab.value[idx]) {
        newActiveTabs[idx - 1] = chainItemActiveTab.value[idx]
      }
      if (chainItemAssertions.value[idx]) {
        newAssertions[idx - 1] = chainItemAssertions.value[idx]
      }
    }
  })
  
  chainItemParams.value = newParams
  expandedChainItems.value = newExpanded
  chainItemActiveTab.value = newActiveTabs
  chainItemAssertions.value = newAssertions
  
  if (chainApis.value.length === 0) {
    activeChainIndex.value = null
  } else if (activeChainIndex.value !== null) {
    if (activeChainIndex.value >= chainApis.value.length) {
      activeChainIndex.value = chainApis.value.length - 1
    }
  }
  
  ElMessage.info(`已移除: ${item.summary || item.path}`)
}

// 切换链接口展开/收起
const toggleChainItemExpand = (index: number) => {
  expandedChainItems.value[index] = !expandedChainItems.value[index]
  // 确保参数已初始化
  initChainItemParams(index)
}

// 打开右侧执行结果抽屉
const openResultDrawer = (index: number) => {
  const r = chainResults.value[index]
  if (!r) return
  resultDrawerContent.value = r
  const apiPath = chainApis.value[index]?.path || '执行结果'
  resultDrawerTitle.value = apiPath
  resultDrawerVisible.value = true
}

// 格式化JSON显示
const formatJSON = (data: any) => {
  if (!data) return ''
  if (typeof data === 'string') {
    try {
      return JSON.stringify(JSON.parse(data), null, 2)
    } catch {
      return data
    }
  }
  return JSON.stringify(data, null, 2)
}

const clearChain = () => {
  ElMessageBox.confirm('确定要清空执行链吗？', '提示', {
    confirmButtonText: '确定',
    cancelButtonText: '取消',
    type: 'warning'
  }).then(() => {
    // 清空执行链
    chainApis.value = []
    chainResults.value = []
    chainItemParams.value = {}
    chainItemActiveTab.value = {}
    expandedChainItems.value = {}
    chainItemAssertions.value = {}
    activeChainIndex.value = null
    // 不清除 currentPlanId 和 planForm，允许清空后保存
    ElMessage.success('已清空执行链，可点击保存更新方案')
  }).catch(() => {})
}

const moveChainItem = (index: number, direction: number) => {
  const newIndex = index + direction
  if (newIndex < 0 || newIndex >= chainApis.value.length) return
  
  // 移动接口
  const item = chainApis.value[index]
  chainApis.value.splice(index, 1)
  chainApis.value.splice(newIndex, 0, item)
  
  // 交换参数配置
  const tempParams = chainItemParams.value[index]
  chainItemParams.value[index] = chainItemParams.value[newIndex]
  chainItemParams.value[newIndex] = tempParams
  
  // 交换展开状态
  const tempExpanded = expandedChainItems.value[index]
  expandedChainItems.value[index] = expandedChainItems.value[newIndex]
  expandedChainItems.value[newIndex] = tempExpanded
  
  // 交换标签页状态
  const tempActiveTab = chainItemActiveTab.value[index]
  chainItemActiveTab.value[index] = chainItemActiveTab.value[newIndex]
  chainItemActiveTab.value[newIndex] = tempActiveTab
  
  // 交换断言配置
  const tempAssertions = chainItemAssertions.value[index]
  chainItemAssertions.value[index] = chainItemAssertions.value[newIndex]
  chainItemAssertions.value[newIndex] = tempAssertions

  if (activeChainIndex.value === index) {
    activeChainIndex.value = newIndex
  } else if (activeChainIndex.value === newIndex) {
    activeChainIndex.value = index
  }
}

// 复制执行链中的单个接口（完整克隆到下一行）
const duplicateChainItem = (index: number) => {
  const apiItem = chainApis.value[index]
  if (!apiItem) return

  const insertIndex = index + 1
  // 1) 复制接口
  const cloneApi = { ...apiItem }
  chainApis.value.splice(insertIndex, 0, cloneApi)

  const oldLength = chainApis.value.length

  // 通用插入辅助：保持与 chainApis 下标对齐
  const insertRecord = <T>(record: Record<number, T>, value: T): Record<number, T> => {
    const newRecord: Record<number, T> = {}
    for (let i = 0; i < oldLength; i++) {
      if (i < insertIndex) {
        newRecord[i] = record[i]
      } else if (i === insertIndex) {
        newRecord[i] = value
      } else {
        newRecord[i] = record[i - 1]
      }
    }
    return newRecord
  }

  // 2) 复制参数
  const clonedParams = JSON.parse(JSON.stringify(chainItemParams.value[index] || { query: '{}', body: '{}', headers: '{}' }))
  chainItemParams.value = insertRecord(chainItemParams.value, clonedParams)

  // 3) 复制断言
  const clonedAssertions = JSON.parse(JSON.stringify(chainItemAssertions.value[index] || [createDefaultAssertion()]))
  chainItemAssertions.value = insertRecord(chainItemAssertions.value, clonedAssertions)

  // 4) 展开状态和 Tab
  chainItemActiveTab.value = insertRecord(chainItemActiveTab.value, chainItemActiveTab.value[index] || 'headers')
  expandedChainItems.value = insertRecord(expandedChainItems.value, false)

  // 5) 结果占位
  chainResults.value.splice(insertIndex, 0, undefined as any)

  ElMessage.success('已复制当前接口')
}

// 替换参数中的引用表达式（支持 $.prev[n] / $.api[n] 与 $.global.xxx）
const replaceParamReferences = (
  paramStr: string, 
  prevResults: any[], 
  globalVars: Record<string, any> = {}
): string => {
  if (!paramStr) return paramStr
  
  // 匹配 $.prev[n].xxx / $.api[n].xxx 格式的引用（包括带引号的）
  // 注意：支持分号、逗号、引号、空格、}、] 等作为结束符
  const prevRegex = /"(\$\.prev\[(\d+)\]\.(.+?))"|(\$\.prev\[(\d+)\]\.(.+?)(?=["'\s,}\];]|$))/g
  const apiRegex = /"(\$\.api\[(\d+)\]\.(.+?))"|(\$\.api\[(\d+)\]\.(.+?)(?=["'\s,}\];]|$))/g
  // 匹配 $.global.xxx
  const globalRegex = /"(\$\.global\.([A-Za-z0-9_]+))"|(\$\.global\.([A-Za-z0-9_]+)(?=["'\s,}\];]|$))/g

  // 解析路径，支持 find(key=value) 语法从数组中查找
  const resolvePath = (obj: any, path: string): any => {
    if (!obj || !path) {
      console.warn('resolvePath: obj 或 path 为空', { obj, path })
      return undefined
    }
    
    const parts = path.split('.')
    let current = obj
    
    console.log('resolvePath 开始:', { obj, path, parts })
    
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]
      console.log(`resolvePath 步骤 ${i}:`, { part, current, currentType: typeof current, isObject: typeof current === 'object' && current !== null })
      
      // 如果当前值是字符串且是 response_body，尝试解析为 JSON
      if (part === 'response_body' && typeof current === 'object' && current !== null) {
        // 检查 response_body 字段
        if (current[part] !== undefined) {
          // 如果是字符串，尝试解析
          if (typeof current[part] === 'string') {
            try {
              const parsed = JSON.parse(current[part])
              current[part] = parsed
              console.log(`解析 response_body 字符串成功:`, parsed)
            } catch (e) {
              // 解析失败，保持原样
              console.warn(`无法解析 response_body 为 JSON:`, e)
            }
          }
          // 如果已经是对象，直接使用
          current = current[part]
          console.log(`访问 response_body 后，current =`, current)
          continue
        } else {
          // 如果 response_body 字段不存在，尝试直接使用 current（可能 current 本身就是 response_body）
          console.warn(`response_body 字段不存在，current =`, current)
          return undefined
        }
      }
      
      // 检查是否是 find(key=value) 语法
      const findMatch = part.match(/^(\w+)\.find\((\w+)=(.+)\)$/)
      if (findMatch) {
        const arrayKey = findMatch[1]
        const filterKey = findMatch[2]
        const filterValue = findMatch[3].replace(/^["']|["']$/g, '') // 移除引号
        
        // 获取数组
        if (!current || !Array.isArray(current[arrayKey])) {
          console.warn(`路径 ${part} 中的 ${arrayKey} 不是数组`)
          return undefined
        }
        
        // 在数组中查找匹配的项
        const found = current[arrayKey].find((item: any) => {
          if (item && typeof item === 'object') {
            const itemValue = item[filterKey]
            // 尝试将 filterValue 转换为数字进行比较
            const numValue = Number(filterValue)
            const numItemValue = Number(itemValue)
            if (!isNaN(numValue) && !isNaN(numItemValue)) {
              return numItemValue === numValue
            }
            return String(itemValue) === String(filterValue)
          }
          return false
        })
        
        if (!found) {
          console.warn(`在 ${arrayKey} 中未找到 ${filterKey}=${filterValue} 的项`)
          return undefined
        }
        
        current = found
        continue
      }
      
      // 检查是否是数组索引访问 [n]
      const arrayIndexMatch = part.match(/^(\w+)\[(\d+)\]$/)
      if (arrayIndexMatch) {
        const arrayKey = arrayIndexMatch[1]
        const arrayIdx = parseInt(arrayIndexMatch[2])
        
        if (!current || !Array.isArray(current[arrayKey])) {
          console.warn(`路径 ${part} 中的 ${arrayKey} 不是数组`)
          return undefined
        }
        
        if (arrayIdx >= current[arrayKey].length) {
          console.warn(`数组索引 ${arrayIdx} 超出范围`)
          return undefined
        }
        
        current = current[arrayKey][arrayIdx]
        continue
      }
      
      // 普通属性访问
      // 支持访问对象属性，也支持访问 null（虽然 typeof null === 'object'，但 null 不能访问属性）
      if (current !== null && current !== undefined) {
        // 如果是对象或数组，检查属性是否存在
        if (typeof current === 'object' && part in current) {
          current = current[part]
          console.log(`访问属性 ${part} 后，current =`, current, `类型:`, typeof current)
        } else if (Array.isArray(current) && /^\d+$/.test(part)) {
          // 如果是数组，支持数字索引
          const idx = parseInt(part)
          if (idx >= 0 && idx < current.length) {
            current = current[idx]
          } else {
            console.warn(`数组索引 ${idx} 超出范围，数组长度:`, current.length)
            return undefined
          }
        } else {
          console.warn(`无法访问属性 ${part}，current 类型:`, typeof current, `current:`, current)
          return undefined
        }
      } else {
        console.warn(`current 为 null 或 undefined，无法访问属性 ${part}`)
        return undefined
      }
    }
    
    return current
  }

  const replacePrev = (match: string, quotedRef: string, quotedIdx: string, quotedPath: string, unquotedRef: string, unquotedIdx: string, unquotedPath: string) => {
    if (quotedRef) {
      const idx = parseInt(quotedIdx)
      const path = quotedPath
      
      if (idx >= prevResults.length || !prevResults[idx]) {
        console.warn(`引用 ${quotedRef} 无效：索引超出范围或结果不存在`)
        return match
      }
      
      try {
        const value = resolvePath(prevResults[idx] as any, path)
        if (value === undefined || value === null) {
          console.warn(`引用 ${quotedRef} 返回 ${value}`)
          return `"undefined"`
        }
        return JSON.stringify(value) as string
      } catch (e) {
        console.error(`解析引用 ${quotedRef} 失败:`, e as Error)
        return match as string
      }
    }
    
    if (unquotedRef) {
      const idx = parseInt(unquotedIdx)
      const path = unquotedPath
      
      if (idx >= prevResults.length || !prevResults[idx]) {
        console.warn(`引用 ${unquotedRef} 无效：索引超出范围或结果不存在`)
        return match
      }
      
      try {
        const value = resolvePath(prevResults[idx] as any, path)
        if (value === undefined || value === null) {
          return `"undefined"`
        }
        return JSON.stringify(value)
      } catch (e) {
        console.error(`解析引用 ${quotedRef} 失败:`, e as Error)
        return match as string
      }
    }
    
    return match
  }

  const replaceApi = (match: string, quotedRef: string, quotedIdx: string, quotedPath: string, unquotedRef: string, unquotedIdx: string, unquotedPath: string) => {
    const handle = (idxStr?: string, path?: string, fullRef?: string) => {
      if (!idxStr) return match
      const apiIdx = parseInt(idxStr, 10) - 1 // 左侧编号从 1 开始
      const targetPath = path
      const refLabel = fullRef || match

      if (apiIdx < 0 || apiIdx >= prevResults.length || !prevResults[apiIdx]) {
        console.warn(`引用 ${refLabel} 无效：索引超出范围或结果不存在`, {
          apiIdx,
          prevResultsLength: prevResults.length,
          prevResults: prevResults
        })
        return match
      }

      try {
        const resultObj = prevResults[apiIdx] as any
        // 添加调试日志
        console.log(`解析引用 ${refLabel}:`, {
          apiIdx,
          targetPath,
          resultObj: resultObj,
          response_body: resultObj.response_body,
          response_body_type: typeof resultObj.response_body
        })
        
        const value = resolvePath(resultObj, targetPath)
        
        console.log(`解析结果:`, {
          refLabel,
          value,
          valueType: typeof value
        })
        
        if (value === undefined || value === null) {
          console.warn(`引用 ${refLabel} 返回 ${value}`)
          return `"undefined"`
        }
        return JSON.stringify(value)
      } catch (e) {
        console.error(`解析引用 ${refLabel} 失败:`, e)
        return match
      }
    }

    if (quotedRef) return handle(quotedIdx, quotedPath, quotedRef)
    if (unquotedRef) return handle(unquotedIdx, unquotedPath, unquotedRef)
    return match
  }

  const replaceGlobal = (match: string, quotedRef: string, quotedKey: string, unquotedRef: string, unquotedKey: string) => {
    const varName = quotedKey || unquotedKey
    if (!varName || !(varName in globalVars)) {
      console.warn(`引用 ${quotedRef || unquotedRef} 无效：全局变量不存在`)
      return match
    }
    const value = globalVars[varName]
    try {
      return JSON.stringify(value)
    } catch (e) {
      console.error(`序列化全局变量 ${varName} 失败:`, e)
      return JSON.stringify(String(value ?? ''))
    }
  }

  return paramStr
    .replace(prevRegex, replacePrev)
    .replace(apiRegex, replaceApi)
    .replace(globalRegex, replaceGlobal)
}

const executeChain = async () => {
  if (!chainEnvironment.value) {
    ElMessage.warning('请选择执行环境')
    return
  }
  
  if (chainApis.value.length === 0) {
    ElMessage.warning('请至少添加一个接口')
    return
  }
  
  chainExecuting.value = true
  chainResults.value = []
  currentExecutingIndex.value = -1
  
  try {
    for (let i = 0; i < chainApis.value.length; i++) {
      currentExecutingIndex.value = i
      const apiItem = chainApis.value[i]
      
    // 每个接口的请求参数对象，需在 try/catch 外定义以便错误时引用
    let params: any = {
          environment_id: chainEnvironment.value
        }
        
      try {
        // 处理query参数
        if (chainItemParams.value[i].query) {
          try {
            const queryStr = replaceParamReferences(chainItemParams.value[i].query, chainResults.value, chainGlobalVarMap.value)
            const queryParams = JSON.parse(queryStr)
            if (Object.keys(queryParams).length > 0) {
              params.query_params = queryParams
            }
          } catch (e) {
            console.error('解析query参数失败:', e)
          }
        }
        
        // 处理body参数
        if (chainItemParams.value[i].body) {
          try {
            const bodyStr = replaceParamReferences(chainItemParams.value[i].body, chainResults.value, chainGlobalVarMap.value)
            const bodyData = JSON.parse(bodyStr)
            if (Object.keys(bodyData).length > 0) {
              params.body = bodyData
            }
          } catch (e) {
            console.warn('解析body参数失败，按原文本发送:', e)
            const bodyStr = replaceParamReferences(chainItemParams.value[i].body, chainResults.value, chainGlobalVarMap.value)
            if (bodyStr && bodyStr.trim().length > 0) {
              params.body = bodyStr
            }
          }
        }
        
        // 处理header参数
        if (chainItemParams.value[i].headers) {
          try {
            const headersStr = replaceParamReferences(chainItemParams.value[i].headers, chainResults.value, chainGlobalVarMap.value)
            const headersData = JSON.parse(headersStr)
            if (Object.keys(headersData).length > 0) {
              params.headers = headersData
            }
          } catch (e) {
            console.error('解析headers参数失败:', e)
          }
        }
        
        // 执行接口
        const result = await api.executeApi(apiItem.id, params)
        
        // 运行断言
        const assertionSummary = runChainAssertions(i, result)
        
        // 判断是否成功：接口执行成功 && 所有断言通过
        const isSuccess = result.success && (!assertionSummary.total || assertionSummary.failed === 0)
        
        // 构建结果消息
        let message = isSuccess ? `成功 - 状态码: ${result.response_status}` : `失败 - 状态码: ${result.response_status}`
        if (assertionSummary.total > 0) {
          if (assertionSummary.failed > 0) {
            message += ` | Assertion: ${assertionSummary.passed}/${assertionSummary.total} passed`
            // 追加首个失败的预期与实际，方便排查
            const firstFail = assertionSummary.failures?.[0]
            if (firstFail) {
              const displayPath = firstFail.path || firstFail.type
              message += ` | ${displayPath}: actual=${firstFail.actual} expected=${firstFail.expected}`
            }
          } else {
            message += ` | Assertion: All passed (${assertionSummary.total})`
          }
        }
        
        chainResults.value.push({
          success: isSuccess as boolean,
          message: message,
          data: result,
          response: result,
          // 将常用字段提升到第一层，方便引用
          response_body: result.response_body,
          response_headers: result.response_headers,
          response_status: result.response_status,
          executedParams: {
            query_params: params.query_params,
            body: params.body,
            headers: params.headers
          },
          assertionSummary: assertionSummary
        })
        
        // 如果失败，自动展开并切换到 Assertion 标签页
        if (!isSuccess) {
          expandedChainItems.value[i] = true
          chainItemActiveTab.value[i] = 'assertions'
          // 使用 nextTick 确保 DOM 更新后再滚动
          await nextTick()
          // 滚动到失败接口位置
          const failedItem = document.querySelector(`.chain-item:nth-child(${i + 1})`)
          if (failedItem) {
            failedItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
          }
        }
        
        // 如果断言失败且设置了失败停止，则中断执行
        if (!isSuccess && chainStopOnError.value) {
          ElMessage.error(`执行在第 ${i + 1} 个接口处停止: ${apiItem.summary || apiItem.path}`)
          break
        }
        
        // 延迟
        if (i < chainApis.value.length - 1 && chainDelay.value > 0) {
          await new Promise(resolve => setTimeout(resolve, chainDelay.value))
        }
      } catch (error: any) {
        const errorMsg = error.response?.data?.detail || error.message || '执行失败'
        const errorData = error.response?.data || {}
        chainResults.value.push({
          success: false,
          message: `失败 - ${errorMsg}`,
          data: errorData,
          response: errorData,
          // 即使失败也提升字段，方便引用错误信息
          response_body: errorData.response_body || errorData,
          response_headers: errorData.response_headers || {},
          response_status: errorData.response_status || (error as any).response?.status,
          executedParams: {
            query_params: params.query_params,
            body: params.body,
            headers: params.headers
          }
        })
        
        // 失败时自动展开并切换到 Assertion 标签页
        expandedChainItems.value[i] = true
        chainItemActiveTab.value[i] = 'assertions'
        // 使用 nextTick 确保 DOM 更新后再滚动
        await nextTick()
        // 滚动到失败接口位置
        const failedItem = document.querySelector(`.chain-item:nth-child(${i + 1})`)
        if (failedItem) {
          failedItem.scrollIntoView({ behavior: 'smooth', block: 'center' })
        }
        
        // 如果设置了失败停止，则中断执行
        if (chainStopOnError.value) {
          ElMessage.error(`执行在第 ${i + 1} 个接口处停止: ${apiItem.summary || apiItem.path}`)
          break
        }
        
        // 失败也要延迟
        if (i < chainApis.value.length - 1 && chainDelay.value > 0) {
          await new Promise(resolve => setTimeout(resolve, chainDelay.value))
        }
      }
    }
    
    const successCount = chainResults.value.filter(r => r.success).length
    const totalCount = chainResults.value.length
    ElMessage.success(`执行完成！成功: ${successCount}/${totalCount}`)
    
  } catch (error: any) {
    ElMessage.error('串联执行出错: ' + (error.message || '未知错误'))
  } finally {
    chainExecuting.value = false
    currentExecutingIndex.value = -1
  }
}

const showChainResultDetail = (index: number) => {
  const result = chainResults.value[index]
  const apiItem = chainApis.value[index]
  
  ElMessageBox.alert(
    `<div style="max-height: 400px; overflow-y: auto;">
      <h4>${apiItem.method} ${apiItem.path}</h4>
      <p><strong>状态:</strong> ${result.success ? '成功' : '失败'}</p>
      <p><strong>消息:</strong> ${result.message}</p>
      ${result.data ? `<pre style="background: #f5f5f5; padding: 10px; border-radius: 4px; overflow-x: auto;">${JSON.stringify(result.data, null, 2)}</pre>` : ''}
    </div>`,
    '执行结果详情',
    {
      dangerouslyUseHTMLString: true,
      confirmButtonText: '关闭'
    }
  )
}

// 串联方案管理方法
const loadChainPlans = async () => {
  try {
    chainPlans.value = await api.getChainPlans()
  } catch (error: any) {
    ElMessage.error('加载串联方案失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 处理保存按钮点击
const handleSaveChain = async () => {
  // 如果有 editingPlanId，说明是点击"✎"编辑按钮进入的，需要弹出对话框
  if (editingPlanId.value) {
    showSavePlanDialog.value = true
    return
  }
  
  // 如果有 currentPlanId 但没有 editingPlanId，说明是点击列表加载的，直接更新
  if (currentPlanId.value && planForm.value.name) {
    try {
      const planData = {
        name: planForm.value.name,
        description: planForm.value.description,
        api_ids: chainApis.value.map(a => a.id),
        api_params: JSON.parse(JSON.stringify(chainItemParams.value)),  // 保存参数配置
        api_assertions: JSON.parse(JSON.stringify(chainItemAssertions.value)),  // 保存断言配置
        global_variables: JSON.parse(JSON.stringify(chainGlobalVarMap.value)),
        environment_id: chainEnvironment.value,
        stop_on_error: chainStopOnError.value,
        delay_ms: chainDelay.value
      }
      
      await api.updateChainPlan(currentPlanId.value, planData)
      ElMessage.success('方案已更新')
      loadChainPlans()
    } catch (error: any) {
      ElMessage.error('保存失败: ' + (error.response?.data?.detail || error.message))
    }
    return
  }
  
  // 新建模式，弹出对话框
  showSavePlanDialog.value = true
}

// 保存当前正在编辑的链接口（需要已有方案）
const saveCurrentChainItem = async () => {
  if (activeChainIndex.value === null) {
    ElMessage.warning('请先选择一个接口')
    return
  }
  const targetPlanId = editingPlanId.value ?? currentPlanId.value
  if (!targetPlanId) {
    showSavePlanDialog.value = true
    ElMessage.info('请先保存或选择一个方案，再保存接口配置')
    return
  }
  try {
    const planData = {
      name: planForm.value.name,
      description: planForm.value.description,
      api_ids: chainApis.value.map(a => a.id),
      api_params: JSON.parse(JSON.stringify(chainItemParams.value)),
      api_assertions: JSON.parse(JSON.stringify(chainItemAssertions.value)),
      global_variables: JSON.parse(JSON.stringify(chainGlobalVarMap.value)),
      environment_id: chainEnvironment.value,
      stop_on_error: chainStopOnError.value,
      delay_ms: chainDelay.value
    }
    await api.updateChainPlan(targetPlanId, planData)
    // 如果原本是 editingPlanId，成功后转为当前方案
    if (editingPlanId.value) {
      currentPlanId.value = editingPlanId.value
      editingPlanId.value = undefined
    }
    ElMessage.success('当前接口配置已保存')
    loadChainPlans()
  } catch (error: any) {
    ElMessage.error('保存当前接口失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 保存全局变量（需要已有方案）
const saveChainGlobalVars = async () => {
  const targetPlanId = editingPlanId.value ?? currentPlanId.value
  if (!targetPlanId) {
    showSavePlanDialog.value = true
    ElMessage.info('请先保存或选择一个方案，再保存全局变量')
    return
  }
  try {
    const planData = {
      name: planForm.value.name,
      description: planForm.value.description,
      api_ids: chainApis.value.map(a => a.id),
      api_params: JSON.parse(JSON.stringify(chainItemParams.value)),
      api_assertions: JSON.parse(JSON.stringify(chainItemAssertions.value)),
      global_variables: JSON.parse(JSON.stringify(chainGlobalVarMap.value)),
      environment_id: chainEnvironment.value,
      stop_on_error: chainStopOnError.value,
      delay_ms: chainDelay.value
    }
    await api.updateChainPlan(targetPlanId, planData)
    if (editingPlanId.value) {
      currentPlanId.value = editingPlanId.value
      editingPlanId.value = undefined
    }
    ElMessage.success('全局变量已保存')
    loadChainPlans()
  } catch (error: any) {
    ElMessage.error('保存全局变量失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 复制全局变量引用
const copyGlobalVarReference = (key?: string) => {
  if (!key) {
    ElMessage.warning('请先填写变量名')
    return
  }
  copyText(`$.global.${key}`, '变量引用')
}


// 安全的深拷贝函数，处理 undefined 和 null
const safeDeepClone = (obj: any): any => {
  if (obj === null || obj === undefined) {
    return null
  }
  
  // 处理字符串、数字、布尔值等基本类型
  if (typeof obj !== 'object') {
    return obj
  }
  
  // 处理 Date 对象
  if (obj instanceof Date) {
    return new Date(obj.getTime())
  }
  
  // 处理数组
  if (Array.isArray(obj)) {
    return obj.map(item => safeDeepClone(item))
  }
  
  // 处理对象
  const cloned: any = {}
  for (const key in obj) {
    if (obj.hasOwnProperty(key)) {
      const value = obj[key]
      // 跳过 undefined 值
      if (value !== undefined) {
        try {
          cloned[key] = safeDeepClone(value)
        } catch (e) {
          // 如果克隆失败，尝试转换为字符串
          console.warn(`克隆字段 ${key} 失败，转换为字符串:`, e)
          cloned[key] = String(value)
        }
      }
    }
  }
  return cloned
}

// 数据清理函数：移除所有 undefined 值，并确保所有值都是可序列化的
const cleanForSerialization = (obj: any, seen = new WeakSet()): any => {
  // 处理 null 和 undefined
  if (obj === null || obj === undefined) {
    return null
  }
  
  // 处理基本类型（字符串、数字、布尔值）
  const objType = typeof obj
  if (objType !== 'object') {
    return obj
  }
  
  // 处理数组
  if (Array.isArray(obj)) {
    return obj.map(item => cleanForSerialization(item, seen))
  }
  
  // 处理对象 - 确保是普通对象
  if (objType === 'object' && obj !== null) {
    // 防止循环引用
    try {
      if (seen.has(obj)) {
        return null
      }
      seen.add(obj)
    } catch (e) {
      // 如果 WeakSet 操作失败（可能是特殊对象），跳过循环引用检查
      console.warn('WeakSet 操作失败，跳过循环引用检查:', e)
    }
    
    // 创建新对象（不使用 Object.create，避免原型问题）
    const cleaned: any = {}
    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        const value = obj[key]
        // 跳过 undefined 值
        if (value !== undefined) {
          try {
            const cleanedValue = cleanForSerialization(value, seen)
            // 确保键名是字符串，值不是 undefined
            if (cleanedValue !== undefined) {
              cleaned[String(key)] = cleanedValue
            }
          } catch (e) {
            console.warn(`清理字段 ${key} 时出错:`, e)
            // 跳过有问题的字段
          }
        }
      }
    }
    return cleaned
  }
  
  // 其他类型（如函数、Symbol等）返回 null
  return null
}

// 保存替换后的参数到数据库
const saveChainParamsAfterReplace = async (planId: number) => {
  if (!planForm.value.name) {
    throw new Error('方案名称为空，无法保存')
  }
  
  // 确保所有接口的参数都已初始化，并清理 undefined 值
  const cleanedParams: Record<number, { query: string; body: string; headers: string }> = {}
  for (let i = 0; i < chainApis.value.length; i++) {
    const original = chainItemParams.value[i]
    if (!original) {
      cleanedParams[i] = {
        query: '{}',
        body: '{}',
        headers: '{}'
      }
    } else {
      // 确保每个字段都是字符串，不能是 undefined 或对象
      cleanedParams[i] = {
        query: typeof original.query === 'string' ? original.query : (original.query ? JSON.stringify(original.query) : '{}'),
        body: typeof original.body === 'string' ? original.body : (original.body ? JSON.stringify(original.body) : '{}'),
        headers: typeof original.headers === 'string' ? original.headers : (original.headers ? JSON.stringify(original.headers) : '{}')
      }
    }
  }
  
  // 清理断言，确保没有 undefined
  const cleanedAssertions: Record<number, any[]> = {}
  for (let i = 0; i < chainApis.value.length; i++) {
    const original = chainItemAssertions.value[i]
    if (Array.isArray(original)) {
      cleanedAssertions[i] = original.filter(a => a !== undefined && a !== null).map(a => ({
        type: a.type || 'status_code',
        path: a.path || '',
        operator: a.operator || 'eq',
        expected: a.expected || '',
        result: a.result,
        actualValue: a.actualValue
      }))
    } else {
      cleanedAssertions[i] = []
    }
  }
  
  // 使用 JSON.stringify/parse 来深拷贝，避免使用可能出错的 safeDeepClone
  let paramsToSave: any
  let assertionsToSave: any
  let globalVarsToSave: any
  
  try {
    // 使用 JSON 序列化/反序列化来深拷贝，同时移除 undefined
    paramsToSave = JSON.parse(JSON.stringify(cleanedParams, (key, value) => {
      return value === undefined ? null : value
    }))
  } catch (e) {
    console.error('❌ 序列化 params 失败:', e)
    // 如果失败，直接使用清理后的数据
    paramsToSave = cleanedParams
  }
  
  try {
    assertionsToSave = JSON.parse(JSON.stringify(cleanedAssertions, (key, value) => {
      return value === undefined ? null : value
    }))
  } catch (e) {
    console.error('❌ 序列化 assertions 失败:', e)
    assertionsToSave = cleanedAssertions
  }
  
  try {
    // 确保 globalVars 是对象
    const globalVars = chainGlobalVarMap.value || {}
    globalVarsToSave = JSON.parse(JSON.stringify(globalVars, (key, value) => {
      return value === undefined ? null : value
    }))
  } catch (e) {
    console.error('❌ 序列化 globalVars 失败:', e)
    // 如果失败，使用空对象
    globalVarsToSave = {}
  }
  
  console.log('💾 准备保存替换后的参数:', {
    planId,
    planName: planForm.value.name,
    apiCount: chainApis.value.length,
    paramsKeys: Object.keys(paramsToSave),
    sampleParam: paramsToSave[0] ? {
      query: paramsToSave[0].query?.substring(0, 50),
      body: paramsToSave[0].body?.substring(0, 50),
      headers: paramsToSave[0].headers?.substring(0, 50)
    } : null
  })
  

  
  // 构建计划数据
  const planDataRaw: any = {
    name: String(planForm.value.name || ''),
    description: String(planForm.value.description || ''),
    api_ids: chainApis.value.map(a => a.id).filter(id => id !== undefined && id !== null),
    api_params: paramsToSave,
    api_assertions: assertionsToSave,
    global_variables: globalVarsToSave,
    stop_on_error: Boolean(chainStopOnError.value ?? true),
    delay_ms: Number(chainDelay.value || 500)
  }
  
  // 只有当 environment_id 存在时才添加
  if (chainEnvironment.value !== undefined && chainEnvironment.value !== null) {
    planDataRaw.environment_id = Number(chainEnvironment.value)
  }
  
  // 使用 JSON.stringify/parse 来彻底清理数据，移除所有不可序列化的值
  let finalData: any
  try {
    // 使用 replacer 函数移除 undefined 值和其他不可序列化的值
    const serializedData = JSON.stringify(planDataRaw, (key, value) => {
      // 移除 undefined 值
      if (value === undefined) {
        return null
      }
      // 移除函数
      if (typeof value === 'function') {
        return null
      }
      // 移除 Symbol
      if (typeof value === 'symbol') {
        return null
      }
      // 确保所有值都是可序列化的
      return value
    })
    
    console.log('✅ 数据序列化成功，长度:', serializedData.length)
    
    // 反序列化得到完全干净的数据
    finalData = JSON.parse(serializedData)
    
    // 再次清理，确保没有遗漏的 undefined
    finalData = JSON.parse(JSON.stringify(finalData, (key, value) => {
      return value === undefined ? null : value
    }))
    
    console.log('📤 发送保存请求，方案ID:', planId, '参数数量:', Object.keys(finalData.api_params || {}).length)
    
    const result = await api.updateChainPlan(planId, finalData)
    console.log('✅ 保存成功，返回结果:', result)
    
    // 如果原本是 editingPlanId，成功后转为当前方案
    if (editingPlanId.value) {
      currentPlanId.value = editingPlanId.value
      editingPlanId.value = undefined
    }
    
    // 刷新方案列表，确保下次加载时能获取最新数据
    await loadChainPlans()
    
    console.log('🔄 方案列表已刷新')
  } catch (error: any) {
    console.error('❌ 保存失败，详细错误:', error)
    throw error
  }
}

const handleSavePlan = async () => {
  if (!planForm.value.name) {
    ElMessage.warning('请输入方案名称')
    return
  }
  
  try {
    const planData = {
      name: planForm.value.name,
      description: planForm.value.description,
      api_ids: chainApis.value.map(a => a.id),
      api_params: JSON.parse(JSON.stringify(chainItemParams.value)),  // 保存参数配置
      api_assertions: JSON.parse(JSON.stringify(chainItemAssertions.value)),  // 保存断言配置
      global_variables: JSON.parse(JSON.stringify(chainGlobalVarMap.value)),
      environment_id: chainEnvironment.value,
      stop_on_error: chainStopOnError.value,
      delay_ms: chainDelay.value
    }
    
    if (editingPlanId.value) {
      // 更新现有方案
      await api.updateChainPlan(editingPlanId.value, planData)
      ElMessage.success('方案已更新')
      
      // 更新 currentPlanId，清除 editingPlanId，切换到直接保存模式
      currentPlanId.value = editingPlanId.value
      editingPlanId.value = undefined
    } else {
      // 创建新方案前，校验名称唯一性
      const nameExists = chainPlans.value.some(p => p.name === planForm.value.name)
      if (nameExists) {
        ElMessage.error(`流程名称 "${planForm.value.name}" 已存在，请使用其他名称`)
        return
      }
      
      // 创建新方案
      const newPlan = await api.createChainPlan(planData)
      ElMessage.success('方案已保存')
      
      // 设置 currentPlanId，以便后续可以直接保存
      currentPlanId.value = newPlan.id
    }
    
    showSavePlanDialog.value = false
    loadChainPlans()
  } catch (error: any) {
    ElMessage.error('保存失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 加载方案到执行链（不自动执行）
const loadPlanToChain = async (plan: api.ChainPlan) => {
  try {
    // 加载方案中的所有接口
    chainApis.value = []
    chainResults.value = []
    chainItemParams.value = {}
    chainItemActiveTab.value = {}
    expandedChainItems.value = {}
    chainItemAssertions.value = {}
    
    for (let i = 0; i < plan.api_ids.length; i++) {
      const apiId = plan.api_ids[i]
      const apiItem = apis.value.find(a => a.id === apiId)
      if (apiItem) {
        chainApis.value.push(apiItem)
        // 初始化每个接口的参数
        initChainItemParams(i)
        
        // 优先加载方案中保存的参数配置
        if (plan.api_params && plan.api_params[i]) {
          const savedParams = plan.api_params[i]
          chainItemParams.value[i] = {
            query: savedParams.query || '{}',
            body: savedParams.body || '{}',
            headers: savedParams.headers || '{}'
          }
        } else {
          // 如果方案中没有保存参数，则加载默认测试数据
          try {
            const testDataList = await api.getTestDataList(apiId)
            if (testDataList.length > 0) {
              const td = await api.getTestData(testDataList[0].id)
              
              fillChainFromTestData(i, td)
            }
          } catch (error) {
            console.error(`加载接口 ${apiId} 的测试数据失败:`, error)
          }
        }
        
        // 加载断言配置
        if (plan.api_assertions && plan.api_assertions[i] && plan.api_assertions[i].length > 0) {
          // 深拷贝，避免后续编辑污染源数据
          chainItemAssertions.value[i] = JSON.parse(JSON.stringify(plan.api_assertions[i]))
        } else {
          chainItemAssertions.value[i] = [createDefaultAssertion()]
        }
      }
    }
    
    if (chainApis.value.length > 0) {
      activeChainIndex.value = 0
    }
    
    // 设置配置
    if (plan.environment_id) {
      chainEnvironment.value = plan.environment_id
    }
    chainStopOnError.value = plan.stop_on_error
    chainDelay.value = plan.delay_ms
    setChainGlobalVars(plan.global_variables)
    
    // 设置当前方案ID（用于直接保存）
    currentPlanId.value = plan.id
    
    // 设置方案名称和描述（用于保存时使用）
    planForm.value.name = plan.name
    planForm.value.description = plan.description || ''
    
    // 清除编辑ID（表示这是通过点击列表加载的，不是编辑模式）
    editingPlanId.value = undefined
    
    // 切换到串联模式
    testMode.value = 'chain'
    
    ElMessage.success(`已加载方案: ${plan.name}`)
  } catch (error: any) {
    ElMessage.error('加载方案失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 加载方案并自动执行
const loadAndExecutePlan = async (plan: api.ChainPlan) => {
  await loadPlanToChain(plan)
  // 自动执行
  await executeChain()
}

const editPlan = async (plan: api.ChainPlan) => {
  // 复用加载逻辑，确保参数/断言/全局变量全部带上
  await loadPlanToChain(plan)
  editingPlanId.value = plan.id
  currentPlanId.value = plan.id
  testMode.value = 'chain'
  showSavePlanDialog.value = true
}

// 导出流程
const exportPlan = async (plan: api.ChainPlan) => {
  try {
    // 获取完整的流程数据
    const fullPlan = await api.getChainPlan(plan.id!)
    
    // 构建导出数据
    const exportData = {
      version: '1.0',
      exportTime: new Date().toISOString(),
      plan: {
        name: fullPlan.name,
        description: fullPlan.description,
        api_ids: fullPlan.api_ids,
        api_params: fullPlan.api_params || {},
        api_assertions: fullPlan.api_assertions || {},
        global_variables: fullPlan.global_variables || {},
        stop_on_error: fullPlan.stop_on_error,
        delay_ms: fullPlan.delay_ms,
        environment_id: fullPlan.environment_id
      }
    }
    
    // 创建JSON文件并下载
    const jsonStr = JSON.stringify(exportData, null, 2)
    const blob = new Blob([jsonStr], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    // 格式化日期时间为 YYYYMMDD_HHmmss 格式
    const now = new Date()
    const year = now.getFullYear()
    const month = String(now.getMonth() + 1).padStart(2, '0')
    const day = String(now.getDate()).padStart(2, '0')
    const hours = String(now.getHours()).padStart(2, '0')
    const minutes = String(now.getMinutes()).padStart(2, '0')
    const seconds = String(now.getSeconds()).padStart(2, '0')
    const timestamp = `${year}${month}${day}_${hours}${minutes}${seconds}`
    link.download = `${fullPlan.name || '流程'}_${timestamp}.json`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
    
    ElMessage.success('流程导出成功')
  } catch (error: any) {
    ElMessage.error('导出失败: ' + (error.response?.data?.detail || error.message))
  }
}

// 导入流程
const handleImportPlan = () => {
  const input = document.createElement('input')
  input.type = 'file'
  input.accept = '.json'
  input.onchange = async (e: any) => {
    const file = e.target.files[0]
    if (!file) return
    
    try {
      const text = await file.text()
      const importData = JSON.parse(text)
      
      if (!importData.plan) {
        ElMessage.error('无效的流程文件格式')
        return
      }
      
      const plan = importData.plan
      
      // 验证必需字段
      if (!plan.name || !plan.api_ids || !Array.isArray(plan.api_ids)) {
        ElMessage.error('流程文件缺少必需字段')
        return
      }
      
      // 加载流程数据到执行链
      await loadImportedPlan(plan)
      
      ElMessage.success('流程导入成功')
    } catch (error: any) {
      ElMessage.error('导入失败: ' + (error.message || '文件格式错误'))
    }
  }
  input.click()
}

// 加载导入的流程数据
const loadImportedPlan = async (planData: any) => {
  try {
    // 清空当前执行链
    chainApis.value = []
    chainResults.value = []
    chainItemParams.value = {}
    chainItemActiveTab.value = {}
    expandedChainItems.value = {}
    chainItemAssertions.value = {}
    
    // 加载接口
    for (let i = 0; i < planData.api_ids.length; i++) {
      const apiId = planData.api_ids[i]
      const apiItem = apis.value.find(a => a.id === apiId)
      if (apiItem) {
        chainApis.value.push(apiItem)
        initChainItemParams(i)
        
        // 加载保存的参数配置
        if (planData.api_params && planData.api_params[i]) {
          const savedParams = planData.api_params[i]
          chainItemParams.value[i] = {
            query: savedParams.query || '{}',
            body: savedParams.body || '{}',
            headers: savedParams.headers || '{}'
          }
        }
        
        // 加载断言配置
        if (planData.api_assertions && planData.api_assertions[i] && planData.api_assertions[i].length > 0) {
          chainItemAssertions.value[i] = JSON.parse(JSON.stringify(planData.api_assertions[i]))
        } else {
          chainItemAssertions.value[i] = [createDefaultAssertion()]
        }
      }
    }
    
    if (chainApis.value.length > 0) {
      activeChainIndex.value = 0
    }
    
    // 设置配置
    if (planData.environment_id) {
      chainEnvironment.value = planData.environment_id
    }
    chainStopOnError.value = planData.stop_on_error !== undefined ? planData.stop_on_error : true
    chainDelay.value = planData.delay_ms || 500
    setChainGlobalVars(planData.global_variables || {})
    
    // 清除编辑ID
    editingPlanId.value = undefined
    
    // 只更新当前选中的流程，不进行任何校验
    const targetPlanId = currentPlanId.value
    
    // 如果有选中的流程，自动保存更新该方案
    if (targetPlanId) {
      // 获取当前流程的原始名称（保持原名称，不更新为导入文件中的名称）
      const currentPlan = chainPlans.value.find(p => p.id === targetPlanId)
      const originalPlanName = currentPlan?.name || planForm.value.name || ''
      
      // 设置方案描述（可以更新描述）
      planForm.value.description = planData.description || ''
      // 保持原流程名称，不更新为导入文件中的名称
      planForm.value.name = originalPlanName
      
      try {
        // 确保所有接口的参数都已初始化，并清理 undefined 值
        const cleanedParams: Record<number, { query: string; body: string; headers: string }> = {}
        for (let i = 0; i < chainApis.value.length; i++) {
          const original = chainItemParams.value[i]
          if (!original) {
            cleanedParams[i] = {
              query: '{}',
              body: '{}',
              headers: '{}'
            }
          } else {
            cleanedParams[i] = {
              query: typeof original.query === 'string' ? original.query : (original.query ? JSON.stringify(original.query) : '{}'),
              body: typeof original.body === 'string' ? original.body : (original.body ? JSON.stringify(original.body) : '{}'),
              headers: typeof original.headers === 'string' ? original.headers : (original.headers ? JSON.stringify(original.headers) : '{}')
            }
          }
        }
        
        // 清理断言，确保没有 undefined
        const cleanedAssertions: Record<number, any[]> = {}
        for (let i = 0; i < chainApis.value.length; i++) {
          const original = chainItemAssertions.value[i]
          if (Array.isArray(original)) {
            cleanedAssertions[i] = original.filter(a => a !== undefined && a !== null).map(a => ({
              type: a.type || 'status_code',
              path: a.path || '',
              operator: a.operator || 'eq',
              expected: a.expected || '',
              result: a.result,
              actualValue: a.actualValue
            }))
          } else {
            cleanedAssertions[i] = []
          }
        }
        
        // 使用安全的深拷贝函数
        const paramsToSave = safeDeepClone(cleanedParams)
        const assertionsToSave = safeDeepClone(cleanedAssertions)
        const globalVarsToSave = safeDeepClone(chainGlobalVarMap.value)
        
        // 构建计划数据（使用原流程名称）
        const planDataRaw: any = {
          name: String(originalPlanName),
          description: String(planForm.value.description || ''),
          api_ids: chainApis.value.map(a => a.id).filter(id => id !== undefined && id !== null),
          api_params: paramsToSave,
          api_assertions: assertionsToSave,
          global_variables: globalVarsToSave,
          stop_on_error: Boolean(chainStopOnError.value ?? true),
          delay_ms: Number(chainDelay.value || 500)
        }
        
        // 只有当 environment_id 存在时才添加
        if (chainEnvironment.value !== undefined && chainEnvironment.value !== null) {
          planDataRaw.environment_id = Number(chainEnvironment.value)
        }
        
        // 清理数据
        const cleanedData = cleanForSerialization(planDataRaw)
        
        // 验证数据可以序列化
        let serializedData: string
        try {
          serializedData = JSON.stringify(cleanedData)
        } catch (e) {
          throw new Error('数据包含无法序列化的值: ' + (e as Error).message)
        }
        
        // 尝试反序列化验证
        try {
          JSON.parse(serializedData)
        } catch (e) {
          throw new Error('序列化验证失败: ' + (e as Error).message)
        }
        
        // 使用序列化后的数据重新解析，确保完全干净
        const finalData = JSON.parse(serializedData)
        await api.updateChainPlan(targetPlanId, finalData)
        
        // 保持选中状态
        currentPlanId.value = targetPlanId
        
        // 刷新流程列表
        await loadChainPlans()
        
        ElMessage.success(`已导入并更新流程: ${originalPlanName}`)
      } catch (error: any) {
        console.error('自动保存导入流程失败:', error)
        ElMessage.warning(`已导入流程数据，但保存失败: ${error.response?.data?.detail || error.message}`)
      }
    } else {
      // 没有选中的流程，只加载数据到界面
      currentPlanId.value = undefined
      ElMessage.warning('请先选择一个流程，再导入文件进行更新')
    }
    
    // 切换到串联模式
    testMode.value = 'chain'
  } catch (error: any) {
    ElMessage.error('加载导入流程失败: ' + (error.response?.data?.detail || error.message))
  }
}

const handleDeletePlan = async (planId: number) => {
  try {
    await ElMessageBox.confirm('确定要删除此串联方案吗？', '提示', {
      type: 'warning'
    })
    
    await api.deleteChainPlan(planId)
    ElMessage.success('方案已删除')
    
    if (currentPlanId.value === planId) {
      currentPlanId.value = undefined
    }
    
    loadChainPlans()
  } catch (error: any) {
    if (error !== 'cancel') {
      ElMessage.error('删除失败: ' + (error.response?.data?.detail || error.message))
    }
  }
}

const formatTime = (time?: string) => {
  if (!time) return ''
  const date = new Date(time)
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  
  if (days === 0) {
    const hours = Math.floor(diff / (1000 * 60 * 60))
    if (hours === 0) {
      const minutes = Math.floor(diff / (1000 * 60))
      return minutes === 0 ? '刚刚' : `${minutes}分钟前`
    }
    return `${hours}小时前`
  } else if (days < 7) {
    return `${days}天前`
  } else {
    return date.toLocaleDateString()
  }
}

// 初始化
onMounted(() => {
  loadEnvironments()
  loadApis()
  loadChainPlans()
})
</script>

<style scoped>
.api-test-container {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
}

/* 头部样式 */
.header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 0 32px;
  height: 70px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
  z-index: 100;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header h1 {
  font-size: 24px;
  margin: 0;
  font-weight: 600;
  letter-spacing: 1px;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

.header-actions {
  display: flex;
  gap: 16px;
  align-items: center;
}

.header-actions :deep(.el-button) {
  padding: 11px 28px;
  font-size: 14px;
  font-weight: 500;
  border-radius: 8px;
  border: none;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  transition: all 0.3s ease;
}

.header-actions :deep(.el-button:hover) {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.3);
}

.header-actions :deep(.el-button:active) {
  transform: translateY(0);
}

/* 主容器 */
.main-container {
  flex: 1;
  overflow: hidden;
  display: flex;
}

/* 左侧边栏 */
.aside {
  background: #ffffff;
  border-right: 1px solid #e4e7ed;
  display: flex;
  flex-direction: column;
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.05);
}

.aside-header {
  padding: 18px 20px;
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  border-bottom: 1px solid #e4e7ed;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.aside-header h3 {
  margin: 0;
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.filter-box {
  padding: 12px 20px;
  background: #ffffff;
  border-bottom: 1px solid #e4e7ed;
}

.filter-box :deep(.el-select) {
  width: 100%;
}

.api-list {
  flex: 1;
  overflow: hidden;
  background: #ffffff;
}

.api-item {
  padding: 14px 20px;
  border-bottom: 1px solid #f0f2f5;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  background: #ffffff;
  position: relative;
}

.api-item::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 3px;
  background: transparent;
  transition: all 0.3s;
}

.api-item:hover {
  background: #f8f9fa;
  padding-left: 24px;
}

.api-item:hover::before {
  background: #409eff;
}

.api-item.active {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding-left: 24px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.api-item.active::before {
  background: #ffffff;
  width: 4px;
}

.api-item.active .api-path {
  color: white;
  font-weight: 600;
}

.api-item.active .api-item-summary {
  color: rgba(255, 255, 255, 0.9);
}

.api-item-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 8px;
}

.api-path {
  font-size: 14px;
  color: #303133;
  font-weight: 500;
  word-break: break-all;
  flex: 1;
}

.api-item-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}

.favorite-btn {
  opacity: 0;
  transition: opacity 0.2s, color 0.2s;
}

.api-item:hover .favorite-btn {
  opacity: 1;
}

.api-item .favorite-btn.is-favorite {
  opacity: 1;
  color: #f56c6c;
}

.api-item-summary {
  font-size: 13px;
  color: #909399;
  margin-bottom: 8px;
  line-height: 1.5;
}

.api-item-tags {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
}

/* 主内容区 */
.main {
  padding: 24px;
  overflow-y: auto;
  background: #f5f7fa;
}

.api-detail {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px 20px 10px 20px;
}

.detail-card {
  margin-bottom: 10px;
  border-radius: 8px;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
  border: 1px solid #e4e7ed;
  overflow: hidden;
}

.detail-card:last-child {
  margin-bottom: 10px;
}

.detail-card :deep(.el-card__header) {
  background: linear-gradient(135deg, #f8f9fa 0%, #ffffff 100%);
  border-bottom: 1px solid #e4e7ed;
  padding: 8px 14px;
}

.detail-card :deep(.el-card__body) {
  padding: 12px;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 20px;
}

.card-header span {
  font-weight: 600;
  font-size: 15px;
  color: #303133;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

/* 请求参数左右布局 */
.params-container {
  display: flex;
  gap: 16px;
}

.params-input-area {
  flex: 1;
  min-width: 0;
}

.test-data-panel {
  width: 240px;
  flex-shrink: 0;
  border-left: 1px solid #e4e7ed;
  padding-left: 16px;
}

.test-data-actions {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.test-data-action-btn {
  width: 100%;
  padding: 10px 12px !important;
  height: auto;
  margin: 0 !important;
  font-size: 14px !important;
  font-weight: 500;
  display: flex;
  justify-content: center;
  align-items: center;
}

.test-data-action-btn :deep(span) {
  font-size: 14px;
  text-align: center;
}

.test-data-list {
  margin-top: 0;
}

.list-title {
  font-size: 14px;
  font-weight: 600;
  color: #303133;
  margin-bottom: 12px;
}

.test-data-items {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.test-data-item {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 10px 12px;
  border-radius: 6px;
  border: 1px solid #e4e7ed;
  background: #ffffff;
  cursor: pointer;
  transition: all 0.3s;
  gap: 8px;
}

.test-data-item:hover {
  border-color: #409eff;
  background: #ecf5ff;
}

.test-data-item.active {
  border-color: #667eea;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.item-content {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  flex: 0 1 auto;
}

.item-icon {
  color: #409eff;
  font-size: 16px;
  flex-shrink: 0;
}

.item-name {
  font-size: 14px;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-align: center;
}

.test-data-item.active .item-name {
  font-weight: 600;
  color: #ffffff;
}

.test-data-item.active .item-icon {
  color: #ffffff;
}

.delete-icon {
  opacity: 0;
  transition: opacity 0.3s;
  flex-shrink: 0;
}

.test-data-item:hover .delete-icon {
  opacity: 1;
}

.empty-list {
  padding: 20px 0;
  text-align: center;
}

.radio-button-content {
  display: flex;
  align-items: center;
  gap: 8px;
}

.delete-btn-inline {
  opacity: 0;
  transition: opacity 0.3s;
  margin-left: 4px;
}

.test-data-buttons :deep(.el-radio-button:hover) .delete-btn-inline {
  opacity: 1;
}

.test-data-buttons :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner) .delete-btn-inline {
  opacity: 0.8;
}

.test-data-buttons :deep(.el-radio-button__original-radio:checked + .el-radio-button__inner:hover) .delete-btn-inline {
  opacity: 1;
}

/* 请求参数卡片特殊样式 */
.request-params-card {
  margin-bottom: 0;
}

/* 测试数据选择器 */
.test-data-selector {
  margin-top: 8px;
}

.test-data-radio-group {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  width: 100%;
  align-items: center;
}

.test-data-radio {
  margin-right: 0 !important;
  margin-bottom: 0 !important;
  height: auto;
  line-height: normal;
}

.test-data-radio :deep(.el-radio__input) {
  display: none;
}

.test-data-radio :deep(.el-radio__label) {
  padding: 0;
  margin-left: 0;
  cursor: pointer;
}

.test-data-option {
  padding: 10px 16px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-width: 120px;
  transition: all 0.3s;
  background: #f8f9fa;
  border: 2px solid #e4e7ed;
  white-space: nowrap;
}

.test-data-radio :deep(.el-radio__input.is-checked ~ .el-radio__label .test-data-option) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-color: #667eea;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.test-data-option:hover {
  border-color: #409eff;
  background: #ecf5ff;
}

.test-data-radio :deep(.el-radio__input.is-checked ~ .el-radio__label .test-data-option:hover) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-color: #667eea;
}

.test-data-option span {
  font-size: 14px;
  flex: 1;
  text-align: center;
}

.test-data-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  text-align: center;
}

.test-data-option .el-icon {
  font-size: 16px;
}

.delete-btn {
  margin-left: 4px;
  opacity: 0.7;
  transition: all 0.3s;
  flex-shrink: 0;
}

.delete-btn:hover {
  opacity: 1;
  transform: scale(1.1);
}

/* 结果区域 */
.result-section {
  margin-top: 12px;
}

.result-section h4 {
  margin-bottom: 8px;
  font-size: 15px;
  color: #606266;
  font-weight: 600;
}

.result-section :deep(.el-textarea__inner) {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 13px;
  line-height: 1.6;
}

/* 响应式设计 */
@media (max-width: 1200px) {
  .api-detail {
    max-width: 100%;
  }
}

/* 滚动条美化 */
:deep(.el-scrollbar__bar) {
  opacity: 0.6;
}

:deep(.el-scrollbar__thumb) {
  background-color: rgba(144, 147, 153, 0.3);
  border-radius: 4px;
}

:deep(.el-scrollbar__thumb:hover) {
  background-color: rgba(144, 147, 153, 0.5);
}

/* Form Data 样式 */
.form-data-container {
  width: 100%;
}

.file-upload-cell {
  display: flex;
  align-items: center;
}

.form-file-upload {
  flex: 1;
}

.form-file-upload :deep(.el-upload-list) {
  display: none;
}

/* 按钮美化 */
:deep(.el-button) {
  border-radius: 6px;
  font-weight: 500;
  transition: all 0.3s;
}

:deep(.el-button:hover) {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

:deep(.el-button:active) {
  transform: translateY(0);
}

/* 输入框美化 */
:deep(.el-input__wrapper) {
  border-radius: 6px;
  box-shadow: 0 0 0 1px #dcdfe6 inset;
  transition: all 0.3s;
}

:deep(.el-input__wrapper:hover) {
  box-shadow: 0 0 0 1px #c0c4cc inset;
}

:deep(.el-input__wrapper.is-focus) {
  box-shadow: 0 0 0 1px #409eff inset;
}

/* 卡片标题美化 */
:deep(.el-card__header) {
  font-weight: 600;
}

/* 描述列表美化 */
:deep(.el-descriptions__label) {
  font-weight: 600;
  color: #606266;
}

/* Tab美化 */
:deep(.el-tabs__item) {
  font-weight: 500;
  transition: all 0.3s;
  padding: 0 16px;
  height: 32px;
  line-height: 32px;
}

:deep(.el-tabs__item.is-active) {
  color: #667eea;
  font-weight: 600;
}

:deep(.el-tabs__active-bar) {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

:deep(.el-tabs__header) {
  margin-bottom: 10px;
}

:deep(.el-tabs__nav-wrap) {
  padding: 0;
}

/* 环境选择下拉样式 */
:deep(.env-select-dropdown .el-select-dropdown__item) {
  height: auto !important;
  min-height: 60px;
  padding: 10px 12px !important;
  line-height: 1.4;
}

:deep(.env-select-dropdown .el-select-dropdown__item:hover) {
  background-color: #f5f7fa;
}

/* 空测试数据样式 */
.empty-test-data {
  padding: 20px;
  text-align: center;
}

.empty-test-data :deep(.el-empty) {
  padding: 20px 0;
}

/* 串联执行模式样式 */

.chain-mode {
  width: 100%;
  padding: 20px;
  box-sizing: border-box;
  height: calc(100vh - 70px);
}

.chain-container {
  display: grid;
  grid-template-columns: minmax(520px, 1fr) 360px;
  gap: 16px;
  height: 100%;
  align-items: stretch;
}

.chain-left-panel {
  width: 100%;
}

.chain-right-panel {
  width: 360px;
  max-width: 380px;
  min-width: 340px;
}
.global-var-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  align-self: stretch;
}
.replace-var-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  align-self: stretch;
}
.replace-var-row {
  display: flex;
  gap: 8px;
  align-items: center;
  width: 100%;
}
.replace-var-row :deep(.el-input) {
  flex: 1;
  min-width: 0;
}
.generate-var-actions {
  display: flex;
  gap: 8px;
  width: 100%;
}
.generate-var-actions .el-button {
  flex: 1;
}
.replace-var-actions {
  display: flex;
  gap: 8px;
  margin-top: 8px;
  width: 100%;
  align-items: flex-start;
}
.replace-var-actions .el-button {
  width: 100%;
  justify-content: center;
}
.global-var-row {
  display: flex;
  gap: 8px;
  align-items: center;
  width: 100%;
}
.global-var-row :deep(.el-input) {
  flex: 1;
}

.global-var-actions {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-top: 8px;
  width: 100%;
  align-items: flex-start;
  align-self: stretch;
  padding: 0 !important;
  margin: 0 !important;
}

.global-var-actions :deep(.el-button) {
  width: 100% !important;
  justify-content: center;
  margin: 0 !important;
}

.chain-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  margin-bottom: 0;
}

.chain-card :deep(.el-card__body) {
  flex: 1;
  overflow: auto;
  padding-bottom: 20px;
}

.chain-card :deep(.el-scrollbar) {
  margin-bottom: 0;
}

.chain-card :deep(.el-scrollbar__view) {
  margin-bottom: 0;
}

.chain-item {
  padding: 15px;
  margin-bottom: 12px;
  background: #f5f7fa;
  border-radius: 8px;
  border: 2px solid transparent;
  transition: all 0.3s;
}

.chain-item:last-child {
  margin-bottom: 0;
}

.chain-item:hover {
  background: #ecf5ff;
  border-color: #409eff;
  transform: translateX(5px);
}

.chain-item.active {
  border-color: #409eff;
  background: #f0f7ff;
}

.chain-item.executing {
  background: #e6f7ff;
  border-color: #91d5ff;
  box-shadow: 0 4px 12px rgba(24, 144, 255, 0.2);
}

.chain-item-header {
  display: flex;
  align-items: center;
  gap: 10px;
}

.chain-order {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-radius: 50%;
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
}

.chain-path {
  flex: 1;
  font-family: 'Courier New', monospace;
  font-size: 13px;
  color: #303133;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chain-actions {
  display: flex;
  gap: 5px;
}

.chain-summary {
  margin-top: 8px;
  padding-left: 38px;
  font-size: 12px;
  color: #909399;
}

.chain-quick-status {
  margin-top: 6px;
  padding-left: 38px;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  font-size: 12px;
}

.status-chip {
  color: #606266;
}

.chain-status-hint {
  color: #a0a3ad;
  font-size: 12px;
}

.chain-status {
  margin-top: 10px;
  padding: 8px 12px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

.chain-status.executing {
  background: #e6f7ff;
  border: 1px solid #91d5ff;
  color: #1890ff;
}

.chain-status.success {
  background: #f0f9ff;
  border: 1px solid #b3e19d;
  color: #52c41a;
}

.chain-status.error {
  background: #fff1f0;
  border: 1px solid #ffccc7;
  color: #ff4d4f;
}

/* 链接口详细内容样式 */
.chain-item-detail {
  margin-top: 15px;
  padding-top: 15px;
}

.chain-item-detail .el-tabs {
  box-shadow: none;
}

.chain-item-detail .el-tabs--border-card {
  border: 1px solid #dcdfe6;
  box-shadow: none;
}

.chain-item-detail .el-tabs--border-card > .el-tabs__content {
  padding: 20px;
  min-height: 300px;
}

.chain-item-detail .el-tab-pane {
  max-height: none;
}

.chain-item-detail .el-tabs__item {
  font-size: 14px;
  padding: 0 20px;
  height: 40px;
  line-height: 40px;
}

.chain-item.expanded {
  background: white;
  border-color: #409eff;
  box-shadow: 0 4px 16px rgba(64, 158, 255, 0.15);
}

.chain-params-section {
  margin-bottom: 0;
}

.chain-assertions-section {
  margin-bottom: 0;
}

.chain-editor-layout {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.chain-editor-left {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.chain-editor-right {
  width: 360px;
  flex-shrink: 0;
}

.chain-section-title {
  font-weight: 600;
  font-size: 14px;
  color: #303133;
  margin: 4px 0;
}

.chain-info {
  margin-bottom: 6px;
}

.chain-current-title {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.chain-header-actions,
.chain-nav-actions {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
  align-items: center;
}

.chain-ref-hint {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}

.chain-result-panel .result-section {
  margin-top: 12px;
}

.chain-result-panel .json-display {
  max-height: 260px;
}

.chain-empty-edit,
.chain-empty-result {
  padding: 20px 0;
}

.result-message {
  font-size: 13px;
  color: #606266;
  line-height: 1.6;
}

.chain-drawer-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 0 12px 0;
  border-bottom: 1px solid #ebeef5;
  margin-bottom: 12px;
}

.drawer-title {
  font-weight: 600;
  font-size: 15px;
  color: #303133;
}

.chain-drawer-content {
  display: grid;
  grid-template-columns: 1.2fr 0.9fr;
  gap: 12px;
}

.chain-drawer-content .chain-editor-right {
  width: 100%;
  min-width: 420px;
}

.chain-result-panel {
  background: #f9fafc;
  border: 1px solid #ebeef5;
  border-radius: 8px;
  padding: 12px;
}

.chain-result-panel .result-summary {
  flex-wrap: wrap;
  gap: 10px;
}

.chain-result-section {
  margin-top: 20px;
  margin-bottom: 20px;
}

.chain-result-section h4 {
  display: flex;
  align-items: center;
  gap: 8px;
  margin: 0 0 15px 0;
  font-size: 14px;
  color: #303133;
  font-weight: 600;
}

.chain-params-section .el-textarea {
  width: 100%;
}

.chain-params-section .el-alert {
  margin-top: 12px;
}

.result-summary {
  display: flex;
  align-items: center;
  gap: 15px;
  margin-bottom: 10px;
  font-size: 13px;
  color: #606266;
}

.result-data {
  margin-top: 10px;
}

.json-display {
  background: #f5f7fa;
  padding: 12px;
  border-radius: 4px;
  font-size: 12px;
  line-height: 1.6;
  max-height: 300px;
  overflow-y: auto;
  margin: 0;
  font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
  white-space: pre-wrap;
  word-break: break-all;
}

.json-display::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

.json-display::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

/* 右侧执行结果面板 */
.slide-left-enter-active,
.slide-left-leave-active {
  transition: all 0.25s ease;
}
.slide-left-enter-from,
.slide-left-leave-to {
  transform: translateX(100%);
  opacity: 0;
}
.result-flyout {
  position: fixed;
  top: 64px;
  right: 0;
  width: 45%;
  height: calc(100vh - 64px);
  background: #fff;
  box-shadow: -4px 0 18px rgba(0, 0, 0, 0.08);
  z-index: 999;
  display: flex;
  flex-direction: column;
  padding: 16px;
  box-sizing: border-box;
}
.result-flyout-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 10px;
  border-bottom: 1px solid #ebeef5;
}
.result-flyout-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  font-weight: 600;
  color: #303133;
}
.result-flyout-body {
  flex: 1;
  overflow: auto; /* 让右侧整体随内容滚动，默认不出现内部滚动条 */
  display: flex;
  flex-direction: column;
}
.result-flyout-tabs {
  flex: 1;
  display: flex;
  flex-direction: column;
}
.result-flyout-tabs :deep(.el-tabs__content) {
  flex: 1;
}
.result-scroll {
  width: 100%;
}
.json-display-tall {
  min-height: 360px;
  max-height: none;
  white-space: pre-wrap;
  word-break: break-all;
}

.param-block {
  margin-bottom: 15px;
}

.param-block:last-child {
  margin-bottom: 0;
}

.param-label {
  font-size: 13px;
  font-weight: 600;
  color: #606266;
  margin-bottom: 8px;
}

.chain-statistics {
  padding: 15px 0;
}

.stat-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
  margin-bottom: 20px;
}

.stat-item {
  background: white;
  padding: 15px;
  border-radius: 8px;
  border: 2px solid #e4e7ed;
  text-align: center;
  transition: all 0.3s;
}

.stat-item:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.stat-item.success {
  border-color: #67c23a;
  background: linear-gradient(135deg, #f0f9ff 0%, #e6f7ff 100%);
}

.stat-item.error {
  border-color: #f56c6c;
  background: linear-gradient(135deg, #fff1f0 0%, #ffe7e7 100%);
}

.stat-label {
  font-size: 12px;
  color: #909399;
  margin-bottom: 8px;
}

.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: #303133;
}

.stat-item.success .stat-value {
  color: #67c23a;
}

.stat-item.error .stat-value {
  color: #f56c6c;
}

.progress-section {
  padding: 15px;
  background: white;
  border-radius: 8px;
  border: 2px solid #e4e7ed;
}

.progress-label {
  font-size: 13px;
  color: #606266;
  margin-bottom: 10px;
  font-weight: 500;
}

.add-to-chain-btn {
  margin-left: auto;
  opacity: 0;
  transition: all 0.3s;
}

.api-item:hover .add-to-chain-btn {
  opacity: 1;
}

.api-item .favorite-btn {
  opacity: 0;
  transition: opacity 0.2s, color 0.2s;
}

.api-item:hover .favorite-btn,
.api-item .favorite-btn.is-favorite {
  opacity: 1;
}

.api-item .favorite-btn.is-favorite {
  color: #f56c6c;
}

/* 右侧串联方案列表样式 */
.chain-plans-aside {
  background: white;
  border-left: 1px solid #e4e7ed;
  padding: 0;
}

.chain-plans-container {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.chain-plans-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20px;
  border-bottom: 2px solid #e4e7ed;
  background: white;
}

.chain-plans-header h3 {
  margin: 0;
  font-size: 16px;
  color: #303133;
  font-weight: 600;
}

.chain-search-box {
  padding: 15px;
  background: white;
  border-bottom: 1px solid #e4e7ed;
}

.empty-plans {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 300px;
}

.plan-list {
  padding: 15px;
}

.plan-item {
  background: white;
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  padding: 15px;
  margin-bottom: 12px;
  transition: all 0.3s;
  cursor: pointer;
}

.plan-item:last-child {
  margin-bottom: 0;
}

.plan-item:hover {
  border-color: #409eff;
  box-shadow: 0 2px 8px rgba(64, 158, 255, 0.15);
}

.plan-item.active {
  border-color: #409eff;
  background: linear-gradient(135deg, #ecf5ff 0%, #e1f0ff 100%);
}

.plan-header {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 10px;
}

.plan-icon {
  color: #667eea;
  font-size: 18px;
}

.plan-name {
  flex: 1;
  font-weight: 600;
  font-size: 15px;
  color: #303133;
}

.plan-actions {
  display: flex;
  gap: 5px;
  opacity: 0;
  transition: opacity 0.3s;
}

.plan-item:hover .plan-actions {
  opacity: 1;
}

.plan-description {
  font-size: 13px;
  color: #606266;
  margin-bottom: 10px;
  line-height: 1.5;
}

.plan-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.plan-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.plan-time {
  font-size: 12px;
  color: #909399;
}

/* 调整中间主区域宽度 */
.main-center {
  flex: 1;
  min-width: 0;
  padding: 0;
  overflow-y: auto;
  background: #f5f7fa;
}

/* 环境下拉菜单美化 */
.env-dropdown-menu {
  min-width: 400px;
  max-width: 600px;
}

.env-dropdown-item {
  font-size: 14px;
  color: #303133;
  padding: 10px 16px !important;
  word-break: break-all;
  white-space: normal;
  line-height: 1.5;
}

/* API Assertion Section Styles */
.api-assertions-section {
  background: transparent;
  border: none;
  border-radius: 0;
  padding: 0;
  min-height: 400px;
}

.api-assertions-section h4 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #409eff;
  display: flex;
  align-items: center;
  gap: 8px;
}

.assertions-list {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.assertion-item {
  background: #ffffff;
  border: 2px solid #e4e7ed;
  border-radius: 8px;
  padding: 16px;
  transition: all 0.3s;
  position: relative;
}

.assertion-item:hover {
  border-color: #409eff;
  box-shadow: 0 2px 12px rgba(64, 158, 255, 0.15);
}

.assertion-row {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: nowrap;
  width: 100%;
}

.assertion-field {
  display: flex;
  align-items: center;
  flex-shrink: 0;
}

.assertion-field :deep(.el-select),
.assertion-field :deep(.el-input) {
  width: 100%;
}

.assertion-actions-inline {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
  flex-shrink: 0;
}

.assertion-actions-inline .el-button {
  width: 32px;
  height: 32px;
  padding: 0;
}

/* 响应式布局 */
@media (max-width: 1200px) {
  .assertion-row {
    flex-wrap: wrap;
  }
  
  .assertion-field {
    min-width: 120px;
  }
  
  .assertion-actions-inline {
    margin-left: 0;
    width: 100%;
    justify-content: flex-end;
    margin-top: 8px;
  }
}

.assertion-form {
  margin-top: 8px;
}

.assertion-actions {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px dashed #e4e7ed;
  display: flex;
  justify-content: flex-end;
}

.assertion-result {
  margin-top: 12px;
  padding: 12px;
  background: #f5f7fa;
  border-radius: 6px;
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.assertion-error {
  font-size: 13px;
  color: #f56c6c;
  background: #fef0f0;
  padding: 4px 8px;
  border-radius: 4px;
}

.empty-assertions {
  padding: 40px 0;
  display: flex;
  justify-content: center;
  align-items: center;
}

/* 串联执行链断言样式美化 */
.chain-assertions-section {
  background: transparent;
  border: none;
  border-radius: 0;
  padding: 0;
  margin-bottom: 0;
}

.assertions-section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.chain-assertions-section h4 {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: #409eff;
  display: flex;
  align-items: center;
  gap: 8px;
}

.chain-assertions-section .assertion-item {
  background: #ffffff;
  border: 2px solid #e4e7ed;
  border-radius: 8px;
  padding: 16px;
  transition: all 0.3s;
  position: relative;
  margin-bottom: 12px;
}

.chain-assertions-section .assertion-item:last-child {
  margin-bottom: 0;
}

.chain-assertions-section .assertion-item:hover {
  border-color: #409eff;
  background: #ffffff;
  box-shadow: 0 2px 12px rgba(64, 158, 255, 0.15);
}


.assertion-number {
  position: absolute;
  top: -10px;
  left: 16px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 4px 12px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
}

.assertion-form {
  margin-top: 12px;
}

.assertion-form .el-form-item {
  margin-bottom: 16px;
}

.assertion-form .el-form-item:last-of-type {
  margin-bottom: 0;
}

.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
  line-height: 1.5;
}

.assertion-actions {
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px dashed #e4e7ed;
  display: flex;
  justify-content: flex-end;
}

.chain-assertions-section .assertions-list {
  display: flex;
  flex-direction: column;
}

.chain-assertions-section .el-button--primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border: none;
}

.chain-assertions-section .el-button--primary:hover {
  background: linear-gradient(135deg, #764ba2 0%, #667eea 100%);
}

.chain-assertions-section .empty-assertions {
  padding: 40px 0;
  background: #ffffff;
  border-radius: 8px;
  border: 2px dashed #e4e7ed;
}

.chain-assertions-section .assertion-result {
  margin-top: 16px;
  padding: 12px;
  background: #f8f9fa;
  border-radius: 6px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.chain-assertions-section .assertion-error {
  font-size: 13px;
  color: #f56c6c;
  background: #fef0f0;
  padding: 6px 12px;
  border-radius: 4px;
  font-weight: 500;
}

/* 前置接口配置样式 */
.variable-extractions {
  width: 100%;
}

.extraction-row {
  display: flex;
  align-items: center;
  margin-bottom: 10px;
}

.form-tip {
  font-size: 12px;
  color: #909399;
  margin-top: 4px;
  line-height: 1.5;
}

.form-tip code {
  background: #f5f7fa;
  padding: 2px 6px;
  border-radius: 3px;
  font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
  color: #e6a23c;
  font-size: 11px;
}

/* 全局前置操作对话框 - 确保内容和标签都左对齐 */
.global-pre-request-dialog .el-dialog__body {
  padding-left: 0 !important;
  padding-right: 20px !important;
}

.global-pre-request-tabs {
  margin-left: 0 !important;
}

.global-pre-request-tabs .el-tab-pane {
  padding-left: 0 !important;
  padding-right: 0 !important;
}

.global-pre-request-tabs .el-form-item__label {
  text-align: left !important;
  justify-content: flex-start !important;
}

.global-pre-request-tabs .el-form-item__content {
  text-align: left;
}

.global-pre-request-tabs .el-input__inner,
.global-pre-request-tabs .el-textarea__inner {
  text-align: left;
}

.global-pre-request-tabs .el-select .el-input__inner {
  text-align: left;
}

.global-pre-request-form {
  margin-left: 0 !important;
  padding-left: 0 !important;
}

.global-pre-request-form .el-form-item__label {
  text-align: left !important;
  justify-content: flex-start !important;
}

.global-pre-request-form .el-form-item__content {
  text-align: left;
}

.global-pre-request-form .el-input__inner,
.global-pre-request-form .el-textarea__inner {
  text-align: left;
}

.global-pre-request-form .el-select .el-input__inner {
  text-align: left;
}
/* 执行详情抽屉样式 */
.execution-detail-container {
  padding: 20px;
}

.execution-detail-item {
  margin-bottom: 24px;
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  overflow: hidden;
}

.execution-detail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: #f5f7fa;
  border-bottom: 1px solid #e4e7ed;
}

.execution-detail-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.execution-index {
  font-weight: 600;
  color: #606266;
}

.execution-path {
  color: #606266;
  font-size: 14px;
}

.execution-detail-content {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0;
}

.execution-detail-request,
.execution-detail-response {
  padding: 16px;
  border-right: 1px solid #e4e7ed;
}

.execution-detail-response {
  border-right: none;
}

.execution-detail-request h4,
.execution-detail-response h4 {
  margin: 0 0 12px 0;
  font-size: 16px;
  font-weight: 600;
  color: #303133;
}

.request-section,
.response-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.param-section {
  margin-bottom: 16px;
}

.param-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
  font-size: 14px;
}

.param-header strong {
  color: #606266;
  font-weight: 600;
}

.empty-params {
  padding: 20px;
  text-align: center;
  color: #909399;
  font-size: 14px;
}

.empty-execution {
  padding: 40px;
  text-align: center;
}

.execution-detail-request .json-display,
.execution-detail-response .json-display {
  max-height: 400px;
  overflow-y: auto;
  margin: 0;
}

</style>


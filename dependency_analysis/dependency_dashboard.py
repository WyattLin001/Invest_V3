#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Invest_V3 實時依賴追蹤儀表板
使用 Dash 創建互動式依賴分析工具

Author: Claude Code Assistant
Version: 1.0.0
"""

import os
import json
import threading
import time
from pathlib import Path
from typing import Dict, List
from datetime import datetime

try:
    import dash
    from dash import dcc, html, Input, Output, callback, dash_table
    import plotly.graph_objects as go
    import plotly.express as px
    import pandas as pd
    import networkx as nx
    HAS_DASH = True
except ImportError:
    HAS_DASH = False
    print("⚠️  Dash 未安裝。安裝命令: pip install dash plotly")

from swift_dependency_analyzer import SwiftDependencyAnalyzer

class InvestV3DependencyDashboard:
    """Invest_V3 依賴追蹤儀表板"""
    
    def __init__(self, project_path: str = "."):
        self.project_path = project_path
        self.analyzer = SwiftDependencyAnalyzer(project_path)
        self.dependency_data = None
        self.last_update = None
        
        # 初始化 Dash 應用
        if HAS_DASH:
            self.app = dash.Dash(__name__, title="Invest_V3 依賴分析儀表板")
            self.setup_layout()
            self.setup_callbacks()
        
        # 監控執行緒
        self.monitoring = False
        self.monitor_thread = None

    def setup_layout(self):
        """設定儀表板佈局"""
        self.app.layout = html.Div([
            # 標題區
            html.Div([
                html.H1("📱 Invest_V3 依賴分析儀表板", 
                       className="dashboard-title"),
                html.P("即時監控 iOS Swift 專案的代碼依賴關係",
                      className="dashboard-subtitle"),
                html.Div(id="last-update", className="last-update")
            ], className="header"),
            
            # 控制面板
            html.Div([
                html.Button("🔄 重新分析", id="refresh-btn", 
                           className="btn btn-primary"),
                html.Button("📊 啟動監控", id="monitor-btn",
                           className="btn btn-secondary"),
                dcc.Dropdown(
                    id="view-selector",
                    options=[
                        {'label': '📈 概覽', 'value': 'overview'},
                        {'label': '🏗️ 架構', 'value': 'architecture'},
                        {'label': '📊 度量', 'value': 'metrics'},
                        {'label': '🔗 依賴圖', 'value': 'network'},
                        {'label': '⚠️ 問題', 'value': 'issues'}
                    ],
                    value='overview',
                    className="view-selector"
                )
            ], className="control-panel"),
            
            # 統計卡片
            html.Div(id="stats-cards", className="stats-container"),
            
            # 主要內容區
            html.Div([
                # 左側面板
                html.Div([
                    html.H3("📊 專案統計"),
                    html.Div(id="project-stats"),
                    html.Hr(),
                    html.H3("📁 檔案列表"),
                    html.Div(id="file-list")
                ], className="left-panel"),
                
                # 右側視覺化區
                html.Div([
                    dcc.Graph(id="main-chart"),
                    html.Div(id="detail-content")
                ], className="right-panel")
            ], className="main-content"),
            
            # 底部表格
            html.Div([
                html.H3("📋 詳細數據"),
                html.Div(id="data-table")
            ], className="bottom-section"),
            
            # 自動更新組件
            dcc.Interval(
                id='auto-update',
                interval=30*1000,  # 30秒更新一次
                n_intervals=0,
                disabled=True
            )
        ])

    def setup_callbacks(self):
        """設定回調函數"""
        
        @self.app.callback(
            [Output('stats-cards', 'children'),
             Output('project-stats', 'children'),
             Output('main-chart', 'figure'),
             Output('file-list', 'children'),
             Output('data-table', 'children'),
             Output('last-update', 'children')],
            [Input('refresh-btn', 'n_clicks'),
             Input('view-selector', 'value'),
             Input('auto-update', 'n_intervals')]
        )
        def update_dashboard(n_clicks, view_type, n_intervals):
            return self._update_dashboard_content(view_type)
        
        @self.app.callback(
            [Output('monitor-btn', 'children'),
             Output('auto-update', 'disabled')],
            [Input('monitor-btn', 'n_clicks')]
        )
        def toggle_monitoring(n_clicks):
            if n_clicks and n_clicks % 2 == 1:
                return "⏹️ 停止監控", False
            else:
                return "📊 啟動監控", True

    def _update_dashboard_content(self, view_type):
        """更新儀表板內容"""
        # 重新分析專案
        try:
            self.dependency_data = self.analyzer.analyze_project()
            self.last_update = datetime.now()
        except Exception as e:
            print(f"❌ 分析失敗: {e}")
            return self._get_error_content()
        
        # 生成統計卡片
        stats_cards = self._create_stats_cards()
        
        # 生成專案統計
        project_stats = self._create_project_stats()
        
        # 生成主圖表
        main_chart = self._create_main_chart(view_type)
        
        # 生成檔案列表
        file_list = self._create_file_list()
        
        # 生成數據表格
        data_table = self._create_data_table(view_type)
        
        # 最後更新時間
        last_update_text = f"最後更新: {self.last_update.strftime('%Y-%m-%d %H:%M:%S')}"
        
        return stats_cards, project_stats, main_chart, file_list, data_table, last_update_text

    def _create_stats_cards(self):
        """創建統計卡片"""
        metrics = self.dependency_data.metrics
        
        cards = [
            self._create_stat_card("📁 總檔案", metrics['total_files'], "個"),
            self._create_stat_card("🔗 依賴關係", metrics['total_dependencies'], "個"),
            self._create_stat_card("📝 代碼行數", f"{metrics['total_lines_of_code']:,}", "行"),
            self._create_stat_card("📊 平均複雜度", metrics['average_complexity'], ""),
            self._create_stat_card("⚠️ 循環依賴", len(self.dependency_data.cycles), "個"),
        ]
        
        return html.Div(cards, className="stats-grid")

    def _create_stat_card(self, title, value, unit):
        """創建單個統計卡片"""
        return html.Div([
            html.H4(title, className="stat-title"),
            html.Div([
                html.Span(str(value), className="stat-value"),
                html.Span(unit, className="stat-unit")
            ], className="stat-content")
        ], className="stat-card")

    def _create_project_stats(self):
        """創建專案統計信息"""
        layers = self.dependency_data.layers
        
        layer_stats = []
        for layer, files in layers.items():
            layer_stats.append(html.Div([
                html.Strong(f"{layer}: "),
                html.Span(f"{len(files)} 檔案")
            ]))
        
        return layer_stats

    def _create_main_chart(self, view_type):
        """創建主要圖表"""
        if view_type == 'overview':
            return self._create_overview_chart()
        elif view_type == 'architecture':
            return self._create_architecture_chart()
        elif view_type == 'metrics':
            return self._create_metrics_chart()
        elif view_type == 'network':
            return self._create_network_chart()
        elif view_type == 'issues':
            return self._create_issues_chart()
        else:
            return self._create_overview_chart()

    def _create_overview_chart(self):
        """創建概覽圖表"""
        layers = self.dependency_data.layers
        
        # 準備數據
        layer_names = list(layers.keys())
        layer_counts = [len(files) for files in layers.values()]
        
        # 創建圓餅圖
        fig = px.pie(
            values=layer_counts,
            names=layer_names,
            title="📊 架構層級分布"
        )
        
        fig.update_traces(textposition='inside', textinfo='percent+label')
        fig.update_layout(
            title_font_size=16,
            font_size=12,
            height=500
        )
        
        return fig

    def _create_architecture_chart(self):
        """創建架構圖表"""
        # 準備複雜度數據
        complexity_data = []
        for file_name, file_info in self.analyzer.swift_files.items():
            complexity_data.append({
                'file': file_name,
                'complexity': file_info.complexity_score,
                'loc': file_info.lines_of_code,
                'dependencies': len(file_info.dependencies)
            })
        
        df = pd.DataFrame(complexity_data)
        
        # 創建散點圖
        fig = px.scatter(
            df, 
            x='loc', 
            y='complexity',
            size='dependencies',
            hover_name='file',
            title="📈 檔案複雜度 vs 代碼行數",
            labels={
                'loc': '代碼行數',
                'complexity': '複雜度分數',
                'dependencies': '依賴數量'
            }
        )
        
        fig.update_layout(height=500)
        return fig

    def _create_metrics_chart(self):
        """創建度量圖表"""
        # 取得最複雜的檔案
        most_complex = self.dependency_data.metrics['most_complex_files'][:10]
        
        files, complexities = zip(*most_complex)
        
        fig = go.Figure(data=[
            go.Bar(x=list(files), y=list(complexities))
        ])
        
        fig.update_layout(
            title="🏆 複雜度排行榜 (前10名)",
            xaxis_title="檔案",
            yaxis_title="複雜度分數",
            height=500
        )
        
        return fig

    def _create_network_chart(self):
        """創建網路圖表"""
        # 建立網路圖
        G = nx.DiGraph()
        
        # 添加節點和邊
        for file_name, file_info in self.analyzer.swift_files.items():
            G.add_node(file_name)
            for dep in file_info.dependencies:
                if dep in self.analyzer.swift_files:
                    G.add_edge(file_name, dep)
        
        # 計算佈局
        try:
            pos = nx.spring_layout(G, k=1, iterations=50)
        except:
            pos = {node: (0, 0) for node in G.nodes()}
        
        # 準備 Plotly 數據
        edge_x, edge_y = [], []
        for edge in G.edges():
            x0, y0 = pos.get(edge[0], (0, 0))
            x1, y1 = pos.get(edge[1], (0, 0))
            edge_x.extend([x0, x1, None])
            edge_y.extend([y0, y1, None])
        
        node_x = [pos.get(node, (0, 0))[0] for node in G.nodes()]
        node_y = [pos.get(node, (0, 0))[1] for node in G.nodes()]
        node_text = list(G.nodes())
        
        # 創建圖表
        fig = go.Figure()
        
        # 添加邊
        fig.add_trace(go.Scatter(x=edge_x, y=edge_y,
                                line=dict(width=0.5, color='#888'),
                                hoverinfo='none',
                                mode='lines'))
        
        # 添加節點
        fig.add_trace(go.Scatter(x=node_x, y=node_y,
                                mode='markers+text',
                                hoverinfo='text',
                                text=node_text,
                                textposition="middle center",
                                marker=dict(size=10,
                                          color='lightblue',
                                          line=dict(width=2, color='DarkSlateGrey'))))
        
        fig.update_layout(
            title="🔗 依賴關係網路圖",
            showlegend=False,
            hovermode='closest',
            margin=dict(b=20,l=5,r=5,t=40),
            xaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            yaxis=dict(showgrid=False, zeroline=False, showticklabels=False),
            height=500
        )
        
        return fig

    def _create_issues_chart(self):
        """創建問題分析圖表"""
        # 收集問題
        issues = []
        
        # 循環依賴
        for cycle in self.dependency_data.cycles:
            issues.append({
                'type': '循環依賴',
                'severity': 'High',
                'description': f"循環: {' → '.join(cycle)}"
            })
        
        # 高複雜度檔案
        for file_name, complexity in self.dependency_data.metrics['most_complex_files'][:5]:
            if complexity > 20:  # 閾值
                issues.append({
                    'type': '高複雜度',
                    'severity': 'Medium',
                    'description': f"{file_name} 複雜度: {complexity}"
                })
        
        # 高依賴檔案
        for file_name, dep_count in self.dependency_data.metrics['most_dependent_files'][:5]:
            if dep_count > 10:  # 閾值
                issues.append({
                    'type': '高依賴',
                    'severity': 'Low',
                    'description': f"{file_name} 依賴: {dep_count}"
                })
        
        if not issues:
            fig = go.Figure()
            fig.add_annotation(
                text="🎉 未發現嚴重問題！",
                xref="paper", yref="paper",
                x=0.5, y=0.5, xanchor='center', yanchor='middle',
                showarrow=False,
                font_size=20
            )
            fig.update_layout(height=500, title="⚠️ 代碼問題分析")
            return fig
        
        # 問題統計
        issue_types = [issue['type'] for issue in issues]
        type_counts = pd.Series(issue_types).value_counts()
        
        fig = px.bar(
            x=type_counts.index,
            y=type_counts.values,
            title="⚠️ 代碼問題統計"
        )
        
        fig.update_layout(
            xaxis_title="問題類型",
            yaxis_title="數量",
            height=500
        )
        
        return fig

    def _create_file_list(self):
        """創建檔案列表"""
        file_items = []
        
        for file_name, file_info in sorted(self.analyzer.swift_files.items()):
            file_items.append(html.Div([
                html.Strong(file_name),
                html.Br(),
                html.Small(f"複雜度: {file_info.complexity_score}, 行數: {file_info.lines_of_code}")
            ], className="file-item"))
        
        return file_items[:20]  # 只顯示前20個檔案

    def _create_data_table(self, view_type):
        """創建數據表格"""
        if view_type == 'overview':
            # 檔案概覽表格
            data = []
            for file_name, file_info in self.analyzer.swift_files.items():
                data.append({
                    '檔案名稱': file_name,
                    '複雜度': file_info.complexity_score,
                    '代碼行數': file_info.lines_of_code,
                    '依賴數量': len(file_info.dependencies),
                    '類別數': len(file_info.classes),
                    '結構數': len(file_info.structs)
                })
        else:
            data = []
        
        if not data:
            return html.Div("暫無數據", className="no-data")
        
        df = pd.DataFrame(data)
        
        return dash_table.DataTable(
            data=df.to_dict('records'),
            columns=[{"name": i, "id": i} for i in df.columns],
            style_cell={'textAlign': 'left'},
            style_header={'backgroundColor': 'rgb(230, 230, 230)', 'fontWeight': 'bold'},
            page_size=10,
            sort_action="native"
        )

    def _get_error_content(self):
        """獲取錯誤內容"""
        error_msg = html.Div([
            html.H3("❌ 分析失敗"),
            html.P("請檢查專案路徑是否正確，或查看控制台錯誤信息。")
        ], className="error-content")
        
        return [error_msg] * 6  # 返回所有輸出的錯誤內容

    def run(self, debug=True, port=8050):
        """運行儀表板"""
        if not HAS_DASH:
            print("❌ Dash 未安裝，無法啟動儀表板")
            return
        
        print(f"🚀 啟動 Invest_V3 依賴分析儀表板...")
        print(f"📱 訪問地址: http://localhost:{port}")
        print("按 Ctrl+C 停止服務")
        
        # 添加 CSS 樣式
        self.app.index_string = '''
        <!DOCTYPE html>
        <html>
            <head>
                {%metas%}
                <title>{%title%}</title>
                {%favicon%}
                {%css%}
                <style>
                    .dashboard-title { color: #2c3e50; text-align: center; margin-bottom: 10px; }
                    .dashboard-subtitle { color: #7f8c8d; text-align: center; margin-bottom: 20px; }
                    .header { background: #ecf0f1; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
                    .control-panel { display: flex; gap: 10px; margin-bottom: 20px; align-items: center; }
                    .btn { padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; }
                    .btn-primary { background: #3498db; color: white; }
                    .btn-secondary { background: #95a5a6; color: white; }
                    .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 20px; }
                    .stat-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); text-align: center; }
                    .stat-title { margin: 0 0 10px 0; color: #34495e; font-size: 14px; }
                    .stat-value { font-size: 24px; font-weight: bold; color: #2c3e50; }
                    .stat-unit { font-size: 12px; color: #7f8c8d; margin-left: 5px; }
                    .main-content { display: grid; grid-template-columns: 300px 1fr; gap: 20px; margin-bottom: 20px; }
                    .left-panel { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
                    .right-panel { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
                    .bottom-section { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
                    .file-item { padding: 8px; border-bottom: 1px solid #ecf0f1; }
                    .last-update { text-align: center; color: #7f8c8d; font-size: 12px; }
                    .view-selector { min-width: 200px; }
                    body { background: #f8f9fa; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; }
                </style>
            </head>
            <body>
                {%app_entry%}
                <footer>
                    {%config%}
                    {%scripts%}
                    {%renderer%}
                </footer>
            </body>
        </html>
        '''
        
        self.app.run_server(debug=debug, port=port, host='0.0.0.0')


def main():
    """主函數"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Invest_V3 實時依賴追蹤儀表板')
    parser.add_argument('--project-path', default='.', help='專案路徑')
    parser.add_argument('--port', type=int, default=8050, help='服務埠號')
    parser.add_argument('--debug', action='store_true', help='偵錯模式')
    
    args = parser.parse_args()
    
    dashboard = InvestV3DependencyDashboard(args.project_path)
    dashboard.run(debug=args.debug, port=args.port)


if __name__ == "__main__":
    main()

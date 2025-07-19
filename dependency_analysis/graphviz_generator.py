#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Invest_V3 Graphviz 依賴圖表生成器
使用 Graphviz 生成精美的依賴關係圖

Author: Claude Code Assistant
Version: 1.0.0
"""

import os
import re
import json
from pathlib import Path
from typing import Dict, List, Set
from dataclasses import dataclass

try:
    import graphviz
    HAS_GRAPHVIZ = True
except ImportError:
    HAS_GRAPHVIZ = False
    print("⚠️  Graphviz 未安裝。安裝命令: pip install graphviz")

@dataclass
class GraphvizConfig:
    """Graphviz 配置"""
    engine: str = 'dot'  # dot, neato, fdp, circo, twopi
    format: str = 'png'  # png, svg, pdf
    dpi: int = 300
    size: str = '20,20'
    bgcolor: str = 'white'
    node_style: str = 'filled,rounded'
    edge_style: str = 'bold'

class InvestV3GraphvizGenerator:
    """Invest_V3 Graphviz 圖表生成器"""
    
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.swift_files = {}
        self.config = GraphvizConfig()
        
        # Invest_V3 特定配色方案
        self.color_scheme = {
            'App': '#FF6B6B',
            'Views': '#4ECDC4', 
            'ViewModels': '#45B7D1',
            'Models': '#96CEB4',
            'Services': '#FECA57',
            'Extensions': '#FF9FF3',
            'Utils': '#54A0FF',
            'Tests': '#5F27CD',
            'Authentication': '#E17055',
            'Trading': '#00B894',
            'Chat': '#0984E3',
            'Article': '#A29BFE',
            'Wallet': '#FDCB6E',
            'Settings': '#6C5CE7',
            'Other': '#DDD'
        }

    def scan_swift_files(self):
        """掃描 Swift 檔案"""
        print("🔍 掃描 Swift 檔案...")
        
        for swift_file in self.project_path.rglob("*.swift"):
            if 'build' in str(swift_file) or '.git' in str(swift_file):
                continue
                
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                file_info = self._analyze_file(swift_file, content)
                self.swift_files[file_info['name']] = file_info
                
            except Exception as e:
                print(f"⚠️  無法讀取 {swift_file}: {e}")
        
        print(f"✅ 發現 {len(self.swift_files)} 個 Swift 檔案")

    def _analyze_file(self, file_path: Path, content: str) -> Dict:
        """分析單個檔案"""
        name = file_path.stem
        
        # 解析 imports
        imports = re.findall(r'^import\s+(\w+)', content, re.MULTILINE)
        
        # 解析類別和結構
        classes = re.findall(r'\bclass\s+(\w+)', content)
        structs = re.findall(r'\bstruct\s+(\w+)', content)
        protocols = re.findall(r'\bprotocol\s+(\w+)', content)
        enums = re.findall(r'\benum\s+(\w+)', content)
        
        # 確定檔案類型和模組
        file_type = self._determine_file_type(name, str(file_path))
        module = self._determine_module(name, content)
        
        # 計算度量
        loc = len([line for line in content.split('\n') if line.strip()])
        complexity = self._calculate_complexity(content)
        
        return {
            'name': name,
            'path': str(file_path.relative_to(self.project_path)),
            'imports': [imp for imp in imports if imp not in ['Foundation', 'UIKit', 'SwiftUI', 'Combine']],
            'classes': classes,
            'structs': structs,
            'protocols': protocols,
            'enums': enums,
            'type': file_type,
            'module': module,
            'loc': loc,
            'complexity': complexity,
            'dependencies': []
        }

    def _determine_file_type(self, name: str, path: str) -> str:
        """確定檔案類型"""
        if 'App.swift' in name:
            return 'App'
        elif 'View' in name and 'Model' not in name:
            return 'Views'
        elif 'ViewModel' in name:
            return 'ViewModels'
        elif 'Model' in name:
            return 'Models'
        elif 'Service' in name or 'Manager' in name:
            return 'Services'
        elif '+' in name or 'Extension' in name:
            return 'Extensions'
        elif 'Test' in name:
            return 'Tests'
        else:
            return 'Other'

    def _determine_module(self, name: str, content: str) -> str:
        """確定檔案所屬模組"""
        modules = {
            'Authentication': ['Auth', 'Login', 'User', 'Profile'],
            'Trading': ['Trading', 'Stock', 'Portfolio', 'Order'],
            'Chat': ['Chat', 'Message', 'Group'],
            'Article': ['Article', 'Content', 'Editor', 'Info'],
            'Wallet': ['Wallet', 'Payment', 'Transaction'],
            'Settings': ['Settings', 'Config']
        }
        
        name_lower = name.lower()
        content_lower = content.lower()
        
        for module, keywords in modules.items():
            for keyword in keywords:
                if keyword.lower() in name_lower or keyword.lower() in content_lower:
                    return module
        
        return 'Core'

    def _calculate_complexity(self, content: str) -> int:
        """計算循環複雜度"""
        keywords = ['if', 'else', 'while', 'for', 'switch', 'case', 'catch', 'guard']
        complexity = 1
        for keyword in keywords:
            complexity += len(re.findall(rf'\b{keyword}\b', content))
        return complexity

    def analyze_dependencies(self):
        """分析依賴關係"""
        print("🔗 分析依賴關係...")
        
        for file_name, file_info in self.swift_files.items():
            dependencies = set()
            
            # 基於 import 的依賴
            for imp in file_info['imports']:
                if imp in self.swift_files:
                    dependencies.add(imp)
            
            # 基於類別引用的依賴
            for other_name, other_info in self.swift_files.items():
                if other_name != file_name:
                    for entity in other_info['classes'] + other_info['structs'] + other_info['protocols']:
                        if entity in str(file_info):
                            dependencies.add(other_name)
            
            file_info['dependencies'] = list(dependencies)

    def generate_overview_graph(self, output_path: str = "dependency_reports"):
        """生成專案概覽圖"""
        if not HAS_GRAPHVIZ:
            print("❌ Graphviz 未安裝，無法生成圖表")
            return
        
        output_dir = Path(output_path)
        output_dir.mkdir(exist_ok=True)
        
        dot = graphviz.Digraph(comment='Invest_V3 專案概覽')
        dot.attr(rankdir='TB', size=self.config.size, dpi=str(self.config.dpi))
        dot.attr('graph', bgcolor=self.config.bgcolor)
        
        # 按模組分組
        modules = {}
        for file_name, file_info in self.swift_files.items():
            module = file_info['module']
            if module not in modules:
                modules[module] = []
            modules[module].append(file_name)
        
        # 為每個模組創建子圖
        for module, files in modules.items():
            color = self.color_scheme.get(module, self.color_scheme['Other'])
            
            with dot.subgraph(name=f'cluster_{module}') as sub:
                sub.attr(label=f'{module} 模組', style='filled', 
                        color='lightgrey', fontsize='16', fontweight='bold')
                
                for file_name in files:
                    file_info = self.swift_files[file_name]
                    
                    # 節點標籤包含複雜度信息
                    label = f"{file_name}\\n({file_info['complexity']})"
                    
                    sub.node(file_name, label=label, 
                           style=self.config.node_style,
                           fillcolor=color,
                           fontsize='10')
        
        # 添加依賴邊
        for file_name, file_info in self.swift_files.items():
            for dep in file_info['dependencies']:
                if dep in self.swift_files:
                    dot.edge(file_name, dep, style=self.config.edge_style)
        
        # 保存圖表
        dot.render(str(output_dir / 'invest_v3_overview'), format=self.config.format, cleanup=True)
        print(f"✅ 概覽圖已生成: {output_dir}/invest_v3_overview.{self.config.format}")

    def generate_architecture_graph(self, output_path: str = "dependency_reports"):
        """生成架構層級圖"""
        if not HAS_GRAPHVIZ:
            return
        
        output_dir = Path(output_path)
        output_dir.mkdir(exist_ok=True)
        
        dot = graphviz.Digraph(comment='Invest_V3 架構層級')
        dot.attr(rankdir='TB', size='16,12', dpi=str(self.config.dpi))
        
        # 按檔案類型分層
        layers = {}
        for file_name, file_info in self.swift_files.items():
            layer = file_info['type']
            if layer not in layers:
                layers[layer] = []
            layers[layer].append(file_name)
        
        # 定義層級順序
        layer_order = ['App', 'Views', 'ViewModels', 'Models', 'Services', 'Extensions', 'Utils', 'Tests', 'Other']
        
        for layer in layer_order:
            if layer in layers:
                color = self.color_scheme.get(layer, self.color_scheme['Other'])
                
                with dot.subgraph(name=f'cluster_{layer}') as sub:
                    sub.attr(label=f'{layer} 層', style='filled', 
                            color='lightgrey', fontsize='14')
                    sub.attr(rank='same')
                    
                    for file_name in layers[layer]:
                        file_info = self.swift_files[file_name]
                        sub.node(file_name, 
                               style=self.config.node_style,
                               fillcolor=color,
                               fontsize='9')
        
        # 添加跨層依賴
        for file_name, file_info in self.swift_files.items():
            for dep in file_info['dependencies']:
                if dep in self.swift_files:
                    dot.edge(file_name, dep, style='dashed', color='gray')
        
        dot.render(str(output_dir / 'invest_v3_architecture'), format=self.config.format, cleanup=True)
        print(f"✅ 架構圖已生成: {output_dir}/invest_v3_architecture.{self.config.format}")

    def generate_module_graphs(self, output_path: str = "dependency_reports"):
        """為每個模組生成詳細圖表"""
        if not HAS_GRAPHVIZ:
            return
        
        output_dir = Path(output_path)
        output_dir.mkdir(exist_ok=True)
        
        # 按模組分組
        modules = {}
        for file_name, file_info in self.swift_files.items():
            module = file_info['module']
            if module not in modules:
                modules[module] = []
            modules[module].append(file_name)
        
        for module, files in modules.items():
            if len(files) < 2:  # 跳過只有一個檔案的模組
                continue
            
            dot = graphviz.Digraph(comment=f'Invest_V3 {module} 模組')
            dot.attr(rankdir='LR', size='12,8', dpi=str(self.config.dpi))
            dot.attr('graph', label=f'{module} 模組依賴圖', fontsize='16', fontweight='bold')
            
            color = self.color_scheme.get(module, self.color_scheme['Other'])
            
            # 添加模組內的檔案
            for file_name in files:
                file_info = self.swift_files[file_name]
                
                # 詳細的節點標籤
                entities = file_info['classes'] + file_info['structs'] + file_info['protocols']
                entity_text = '\\n'.join(entities[:3])  # 只顯示前3個
                if len(entities) > 3:
                    entity_text += f'\\n... (+{len(entities)-3})'
                
                label = f"{file_name}\\n{entity_text}\\nLOC: {file_info['loc']}"
                
                dot.node(file_name, label=label,
                        style=self.config.node_style,
                        fillcolor=color,
                        fontsize='10',
                        shape='box')
            
            # 添加模組內依賴
            for file_name in files:
                file_info = self.swift_files[file_name]
                for dep in file_info['dependencies']:
                    if dep in files:
                        dot.edge(file_name, dep, style=self.config.edge_style)
            
            # 添加對外依賴 (虛線)
            for file_name in files:
                file_info = self.swift_files[file_name]
                for dep in file_info['dependencies']:
                    if dep not in files and dep in self.swift_files:
                        dep_module = self.swift_files[dep]['module']
                        dot.node(dep, label=f"{dep}\\n({dep_module})",
                               style='dashed',
                               fillcolor='lightgray',
                               fontsize='9')
                        dot.edge(file_name, dep, style='dashed', color='gray')
            
            dot.render(str(output_dir / f'invest_v3_module_{module.lower()}'), 
                      format=self.config.format, cleanup=True)
            print(f"✅ {module} 模組圖已生成")

    def generate_complexity_graph(self, output_path: str = "dependency_reports"):
        """生成複雜度視覺化圖"""
        if not HAS_GRAPHVIZ:
            return
        
        output_dir = Path(output_path)
        output_dir.mkdir(exist_ok=True)
        
        dot = graphviz.Digraph(comment='Invest_V3 複雜度分析')
        dot.attr(rankdir='TB', size='16,12', dpi=str(self.config.dpi))
        dot.attr('graph', label='檔案複雜度分析 (節點大小表示複雜度)', fontsize='16')
        
        # 計算複雜度範圍
        complexities = [info['complexity'] for info in self.swift_files.values()]
        min_complexity = min(complexities)
        max_complexity = max(complexities)
        
        for file_name, file_info in self.swift_files.items():
            # 根據複雜度設定節點大小和顏色
            complexity = file_info['complexity']
            
            # 正規化複雜度 (0-1)
            if max_complexity > min_complexity:
                norm_complexity = (complexity - min_complexity) / (max_complexity - min_complexity)
            else:
                norm_complexity = 0
            
            # 節點大小 (0.5-2.0)
            node_size = 0.5 + norm_complexity * 1.5
            
            # 顏色強度 (綠色到紅色)
            if norm_complexity < 0.3:
                color = '#90EE90'  # 淺綠
            elif norm_complexity < 0.7:
                color = '#FFD700'  # 金色
            else:
                color = '#FF6B6B'  # 紅色
            
            label = f"{file_name}\\n複雜度: {complexity}\\nLOC: {file_info['loc']}"
            
            dot.node(file_name, label=label,
                    style=self.config.node_style,
                    fillcolor=color,
                    fontsize='9',
                    width=str(node_size),
                    height=str(node_size))
        
        # 添加依賴邊
        for file_name, file_info in self.swift_files.items():
            for dep in file_info['dependencies']:
                if dep in self.swift_files:
                    dot.edge(file_name, dep, style='dashed', color='lightgray')
        
        dot.render(str(output_dir / 'invest_v3_complexity'), format=self.config.format, cleanup=True)
        print(f"✅ 複雜度圖已生成: {output_dir}/invest_v3_complexity.{self.config.format}")

    def generate_all_graphs(self, output_path: str = "dependency_reports"):
        """生成所有圖表"""
        print("🎨 生成 Graphviz 依賴圖表...")
        
        self.scan_swift_files()
        self.analyze_dependencies()
        
        self.generate_overview_graph(output_path)
        self.generate_architecture_graph(output_path)
        self.generate_module_graphs(output_path)
        self.generate_complexity_graph(output_path)
        
        print("🎉 Graphviz 圖表生成完成！")

    def export_dot_files(self, output_path: str = "dependency_reports"):
        """匯出 .dot 檔案供進階編輯"""
        output_dir = Path(output_path)
        output_dir.mkdir(exist_ok=True)
        
        # 生成通用 DOT 檔案
        with open(output_dir / 'invest_v3_dependencies.dot', 'w', encoding='utf-8') as f:
            f.write('digraph "Invest_V3_Dependencies" {\n')
            f.write('  rankdir=TB;\n')
            f.write('  node [style="filled,rounded" fontname="Arial"];\n')
            f.write('  edge [fontname="Arial"];\n\n')
            
            # 節點定義
            for file_name, file_info in self.swift_files.items():
                color = self.color_scheme.get(file_info['module'], self.color_scheme['Other'])
                f.write(f'  "{file_name}" [fillcolor="{color}" label="{file_name}\\n({file_info["complexity"]})"];\n')
            
            f.write('\n')
            
            # 邊定義
            for file_name, file_info in self.swift_files.items():
                for dep in file_info['dependencies']:
                    if dep in self.swift_files:
                        f.write(f'  "{file_name}" -> "{dep}";\n')
            
            f.write('}\n')
        
        print(f"✅ DOT 檔案已匯出: {output_dir}/invest_v3_dependencies.dot")


def main():
    """主函數"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Invest_V3 Graphviz 依賴圖表生成器')
    parser.add_argument('--project-path', default='.', help='專案路徑')
    parser.add_argument('--output-dir', default='dependency_reports', help='輸出目錄')
    parser.add_argument('--format', choices=['png', 'svg', 'pdf'], default='png', help='圖片格式')
    parser.add_argument('--engine', choices=['dot', 'neato', 'fdp', 'circo', 'twopi'], default='dot', help='佈局引擎')
    
    args = parser.parse_args()
    
    print("🚀 Invest_V3 Graphviz 依賴圖表生成器")
    print("=" * 50)
    
    generator = InvestV3GraphvizGenerator(args.project_path)
    generator.config.format = args.format
    generator.config.engine = args.engine
    
    generator.generate_all_graphs(args.output_dir)
    generator.export_dot_files(args.output_dir)


if __name__ == "__main__":
    main()

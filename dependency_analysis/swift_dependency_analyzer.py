#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Invest_V3 Swift Dependency Analyzer
分析 iOS Swift 專案的代碼依賴關係並生成視覺化圖表

Author: Claude Code Assistant
Version: 1.0.0
Date: 2025-07-19
"""

import os
import re
import json
import argparse
from typing import Dict, List, Set, Tuple
from pathlib import Path
from dataclasses import dataclass, asdict
from collections import defaultdict, Counter

try:
    import networkx as nx
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    from matplotlib.colors import LinearSegmentedColormap
    import pandas as pd
    import seaborn as sns
    HAS_VISUALIZATION = True
except ImportError:
    HAS_VISUALIZATION = False
    print("⚠️  可視化庫未安裝。安裝命令: pip install networkx matplotlib pandas seaborn")

@dataclass
class SwiftFile:
    """Swift 檔案資訊"""
    name: str
    path: str
    imports: List[str]
    classes: List[str]
    protocols: List[str]
    structs: List[str]
    enums: List[str]
    extensions: List[str]
    dependencies: List[str]
    complexity_score: int
    lines_of_code: int

@dataclass
class DependencyGraph:
    """依賴圖資訊"""
    nodes: List[str]
    edges: List[Tuple[str, str]]
    cycles: List[List[str]]
    layers: Dict[str, List[str]]
    metrics: Dict[str, any]

class SwiftDependencyAnalyzer:
    """Swift 代碼依賴分析器"""
    
    def __init__(self, project_path: str):
        self.project_path = Path(project_path)
        self.swift_files: Dict[str, SwiftFile] = {}
        self.dependency_graph = None
        
        # iOS 架構層級定義
        self.architecture_layers = {
            'App': ['App.swift', 'main.swift'],
            'Views': ['View.swift', 'ViewController.swift'],
            'ViewModels': ['ViewModel.swift'],
            'Models': ['Model.swift', 'Entity.swift'],
            'Services': ['Service.swift', 'Manager.swift'],
            'Extensions': ['Extension.swift', '+'],
            'Utils': ['Util.swift', 'Helper.swift'],
            'Tests': ['Test.swift', 'Tests.swift']
        }
        
        # 設計模式檢測
        self.design_patterns = {
            'MVVM': ['ViewModel', 'ObservableObject'],
            'Singleton': ['shared', 'instance'],
            'Factory': ['Factory', 'Builder'],
            'Observer': ['Publisher', 'Subscriber', 'NotificationCenter'],
            'Delegate': ['Delegate', 'DataSource']
        }
        
        # Invest_V3 特定模組
        self.invest_modules = {
            'Authentication': ['Auth', 'Login', 'User'],
            'Trading': ['Trading', 'Stock', 'Portfolio'],
            'Chat': ['Chat', 'Message', 'Group'],
            'Article': ['Article', 'Content', 'Editor'],
            'Wallet': ['Wallet', 'Payment', 'Transaction'],
            'Settings': ['Settings', 'Profile', 'Config']
        }

    def analyze_project(self) -> DependencyGraph:
        """分析整個專案的依賴關係"""
        print("🔍 開始分析 Invest_V3 專案依賴關係...")
        
        # 1. 掃描所有 Swift 檔案
        self._scan_swift_files()
        
        # 2. 分析檔案間依賴
        self._analyze_dependencies()
        
        # 3. 建立依賴圖
        dependency_graph = self._build_dependency_graph()
        
        # 4. 檢測循環依賴
        cycles = self._detect_cycles()
        
        # 5. 分析架構層級
        layers = self._analyze_architecture_layers()
        
        # 6. 計算度量指標
        metrics = self._calculate_metrics()
        
        self.dependency_graph = DependencyGraph(
            nodes=list(self.swift_files.keys()),
            edges=self._get_all_edges(),
            cycles=cycles,
            layers=layers,
            metrics=metrics
        )
        
        print(f"✅ 分析完成！發現 {len(self.swift_files)} 個檔案，{len(self.dependency_graph.edges)} 個依賴關係")
        return self.dependency_graph

    def _scan_swift_files(self):
        """掃描所有 Swift 檔案"""
        swift_pattern = re.compile(r'\.swift$')
        
        for root, dirs, files in os.walk(self.project_path):
            # 跳過不必要的目錄
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['build', 'DerivedData']]
            
            for file in files:
                if swift_pattern.search(file):
                    file_path = Path(root) / file
                    swift_file = self._analyze_swift_file(file_path)
                    if swift_file:
                        self.swift_files[swift_file.name] = swift_file

    def _analyze_swift_file(self, file_path: Path) -> SwiftFile:
        """分析單個 Swift 檔案"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except Exception as e:
            print(f"⚠️  無法讀取檔案 {file_path}: {e}")
            return None
        
        # 解析 import 語句
        imports = re.findall(r'^import\s+(\w+)', content, re.MULTILINE)
        
        # 解析類別、協議、結構體、列舉
        classes = re.findall(r'\bclass\s+(\w+)', content)
        protocols = re.findall(r'\bprotocol\s+(\w+)', content)
        structs = re.findall(r'\bstruct\s+(\w+)', content)
        enums = re.findall(r'\benum\s+(\w+)', content)
        extensions = re.findall(r'\bextension\s+(\w+)', content)
        
        # 計算代碼複雜度和行數
        lines_of_code = len([line for line in content.split('\n') if line.strip() and not line.strip().startswith('//')])
        complexity_score = self._calculate_complexity(content)
        
        return SwiftFile(
            name=file_path.stem,
            path=str(file_path.relative_to(self.project_path)),
            imports=imports,
            classes=classes,
            protocols=protocols,
            structs=structs,
            enums=enums,
            extensions=extensions,
            dependencies=[],  # 將在下一步填入
            complexity_score=complexity_score,
            lines_of_code=lines_of_code
        )

    def _calculate_complexity(self, content: str) -> int:
        """計算代碼複雜度"""
        # 簡單的循環複雜度計算
        complexity_keywords = [
            'if', 'else', 'while', 'for', 'switch', 'case', 'catch', 'guard'
        ]
        score = 1  # 基礎複雜度
        for keyword in complexity_keywords:
            score += len(re.findall(rf'\b{keyword}\b', content))
        return score

    def _analyze_dependencies(self):
        """分析檔案間的依賴關係"""
        for file_name, swift_file in self.swift_files.items():
            dependencies = []
            
            # 基於 import 的依賴
            for imp in swift_file.imports:
                if imp not in ['Foundation', 'UIKit', 'SwiftUI', 'Combine']:  # 跳過系統框架
                    dependencies.append(imp)
            
            # 基於類別引用的依賴
            for other_file_name, other_file in self.swift_files.items():
                if other_file_name != file_name:
                    # 檢查是否引用了其他檔案的類別
                    for cls in other_file.classes + other_file.structs + other_file.protocols:
                        if cls in str(swift_file.__dict__):
                            dependencies.append(other_file_name)
            
            swift_file.dependencies = list(set(dependencies))

    def _build_dependency_graph(self) -> nx.DiGraph:
        """建立依賴圖"""
        graph = nx.DiGraph()
        
        # 添加節點
        for file_name, swift_file in self.swift_files.items():
            graph.add_node(file_name, **asdict(swift_file))
        
        # 添加邊
        for file_name, swift_file in self.swift_files.items():
            for dependency in swift_file.dependencies:
                if dependency in self.swift_files:
                    graph.add_edge(file_name, dependency)
        
        return graph

    def _detect_cycles(self) -> List[List[str]]:
        """檢測循環依賴"""
        if not hasattr(self, '_graph'):
            self._graph = self._build_dependency_graph()
        
        try:
            cycles = list(nx.simple_cycles(self._graph))
            return cycles
        except:
            return []

    def _analyze_architecture_layers(self) -> Dict[str, List[str]]:
        """分析架構層級"""
        layers = defaultdict(list)
        
        for file_name, swift_file in self.swift_files.items():
            layer_found = False
            
            # 根據檔案名稱和路徑判斷層級
            for layer, patterns in self.architecture_layers.items():
                for pattern in patterns:
                    if pattern.lower() in file_name.lower() or pattern.lower() in swift_file.path.lower():
                        layers[layer].append(file_name)
                        layer_found = True
                        break
                if layer_found:
                    break
            
            # 如果沒有匹配，歸類為 Other
            if not layer_found:
                layers['Other'].append(file_name)
        
        return dict(layers)

    def _calculate_metrics(self) -> Dict[str, any]:
        """計算專案度量指標"""
        if not hasattr(self, '_graph'):
            self._graph = self._build_dependency_graph()
        
        total_files = len(self.swift_files)
        total_dependencies = sum(len(f.dependencies) for f in self.swift_files.values())
        total_loc = sum(f.lines_of_code for f in self.swift_files.values())
        avg_complexity = sum(f.complexity_score for f in self.swift_files.values()) / total_files if total_files > 0 else 0
        
        return {
            'total_files': total_files,
            'total_dependencies': total_dependencies,
            'total_lines_of_code': total_loc,
            'average_complexity': round(avg_complexity, 2),
            'dependency_density': round(total_dependencies / total_files, 2) if total_files > 0 else 0,
            'most_complex_files': sorted(
                [(f.name, f.complexity_score) for f in self.swift_files.values()],
                key=lambda x: x[1], reverse=True
            )[:5],
            'most_dependent_files': sorted(
                [(f.name, len(f.dependencies)) for f in self.swift_files.values()],
                key=lambda x: x[1], reverse=True
            )[:5]
        }

    def _get_all_edges(self) -> List[Tuple[str, str]]:
        """獲取所有依賴邊"""
        edges = []
        for file_name, swift_file in self.swift_files.items():
            for dependency in swift_file.dependencies:
                if dependency in self.swift_files:
                    edges.append((file_name, dependency))
        return edges

    def generate_reports(self, output_dir: str = "dependency_reports"):
        """生成各種報告"""
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        print(f"📊 生成依賴分析報告到 {output_path}")
        
        # 1. JSON 數據報告
        self._generate_json_report(output_path)
        
        # 2. Markdown 報告
        self._generate_markdown_report(output_path)
        
        # 3. 視覺化圖表 (如果可用)
        if HAS_VISUALIZATION:
            self._generate_visualizations(output_path)
        
        print("✅ 報告生成完成！")

    def _generate_json_report(self, output_path: Path):
        """生成 JSON 格式報告"""
        report_data = {
            'project_info': {
                'name': 'Invest_V3',
                'analysis_date': str(pd.Timestamp.now()),
                'project_path': str(self.project_path)
            },
            'files': {name: asdict(file) for name, file in self.swift_files.items()},
            'dependency_graph': asdict(self.dependency_graph) if self.dependency_graph else None
        }
        
        with open(output_path / 'dependency_analysis.json', 'w', encoding='utf-8') as f:
            json.dump(report_data, f, ensure_ascii=False, indent=2, default=str)

    def _generate_markdown_report(self, output_path: Path):
        """生成 Markdown 格式報告"""
        with open(output_path / 'dependency_report.md', 'w', encoding='utf-8') as f:
            f.write("# Invest_V3 依賴分析報告\n\n")
            f.write(f"**生成時間**: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            # 專案概覽
            f.write("## 📊 專案概覽\n\n")
            metrics = self.dependency_graph.metrics
            f.write(f"- **總檔案數**: {metrics['total_files']}\n")
            f.write(f"- **總依賴關係**: {metrics['total_dependencies']}\n")
            f.write(f"- **總代碼行數**: {metrics['total_lines_of_code']}\n")
            f.write(f"- **平均複雜度**: {metrics['average_complexity']}\n")
            f.write(f"- **依賴密度**: {metrics['dependency_density']}\n\n")
            
            # 架構層級
            f.write("## 🏗️ 架構層級\n\n")
            for layer, files in self.dependency_graph.layers.items():
                f.write(f"### {layer} ({len(files)} 檔案)\n")
                for file in files:
                    f.write(f"- {file}\n")
                f.write("\n")
            
            # 循環依賴
            if self.dependency_graph.cycles:
                f.write("## ⚠️ 循環依賴\n\n")
                for i, cycle in enumerate(self.dependency_graph.cycles, 1):
                    f.write(f"### 循環 {i}\n")
                    f.write(" → ".join(cycle + [cycle[0]]) + "\n\n")
            else:
                f.write("## ✅ 無循環依賴\n\n")
            
            # 複雜度排行
            f.write("## 📈 複雜度排行 (前 10 名)\n\n")
            f.write("| 檔案 | 複雜度 | 代碼行數 | 依賴數 |\n")
            f.write("|------|--------|----------|--------|\n")
            
            for file_name, file_info in sorted(
                self.swift_files.items(), 
                key=lambda x: x[1].complexity_score, 
                reverse=True
            )[:10]:
                f.write(f"| {file_name} | {file_info.complexity_score} | {file_info.lines_of_code} | {len(file_info.dependencies)} |\n")

    def _generate_visualizations(self, output_path: Path):
        """生成視覺化圖表"""
        print("🎨 生成視覺化圖表...")
        
        # 1. 依賴關係網路圖
        self._plot_dependency_network(output_path)
        
        # 2. 架構層級圖
        self._plot_architecture_layers(output_path)
        
        # 3. 複雜度熱力圖
        self._plot_complexity_heatmap(output_path)
        
        # 4. 依賴矩陣
        self._plot_dependency_matrix(output_path)

    def _plot_dependency_network(self, output_path: Path):
        """繪製依賴關係網路圖"""
        if not hasattr(self, '_graph'):
            self._graph = self._build_dependency_graph()
        
        plt.figure(figsize=(16, 12))
        
        # 設定節點顏色（根據架構層級）
        layer_colors = {
            'App': '#FF6B6B', 'Views': '#4ECDC4', 'ViewModels': '#45B7D1',
            'Models': '#96CEB4', 'Services': '#FECA57', 'Extensions': '#FF9FF3',
            'Utils': '#54A0FF', 'Tests': '#5F27CD', 'Other': '#C7ECEE'
        }
        
        node_colors = []
        for node in self._graph.nodes():
            node_layer = 'Other'
            for layer, files in self.dependency_graph.layers.items():
                if node in files:
                    node_layer = layer
                    break
            node_colors.append(layer_colors.get(node_layer, '#C7ECEE'))
        
        # 設定佈局
        pos = nx.spring_layout(self._graph, k=3, iterations=50)
        
        # 繪製網路
        nx.draw(self._graph, pos, 
                node_color=node_colors,
                node_size=1000,
                font_size=8,
                font_weight='bold',
                edge_color='gray',
                alpha=0.7,
                arrows=True,
                arrowsize=20)
        
        # 添加圖例
        legend_elements = [mpatches.Patch(color=color, label=layer) 
                          for layer, color in layer_colors.items()]
        plt.legend(handles=legend_elements, loc='upper right', bbox_to_anchor=(1.15, 1))
        
        plt.title('Invest_V3 依賴關係網路圖', fontsize=16, fontweight='bold')
        plt.tight_layout()
        plt.savefig(output_path / 'dependency_network.png', dpi=300, bbox_inches='tight')
        plt.close()

    def _plot_architecture_layers(self, output_path: Path):
        """繪製架構層級圖"""
        layer_data = [(layer, len(files)) for layer, files in self.dependency_graph.layers.items()]
        layers, counts = zip(*layer_data)
        
        plt.figure(figsize=(12, 8))
        colors = plt.cm.Set3(range(len(layers)))
        
        bars = plt.bar(layers, counts, color=colors, alpha=0.8)
        
        # 添加數值標籤
        for bar in bars:
            height = bar.get_height()
            plt.text(bar.get_x() + bar.get_width()/2., height + 0.1,
                    f'{int(height)}', ha='center', va='bottom', fontweight='bold')
        
        plt.title('Invest_V3 架構層級分布', fontsize=16, fontweight='bold')
        plt.xlabel('架構層級', fontsize=12)
        plt.ylabel('檔案數量', fontsize=12)
        plt.xticks(rotation=45)
        plt.grid(axis='y', alpha=0.3)
        plt.tight_layout()
        plt.savefig(output_path / 'architecture_layers.png', dpi=300, bbox_inches='tight')
        plt.close()

    def _plot_complexity_heatmap(self, output_path: Path):
        """繪製複雜度熱力圖"""
        # 準備數據
        files = list(self.swift_files.keys())[:20]  # 只顯示前20個檔案
        complexity_data = [[self.swift_files[f].complexity_score for f in files]]
        
        plt.figure(figsize=(16, 4))
        sns.heatmap(complexity_data, 
                   xticklabels=[f[:15] + '...' if len(f) > 15 else f for f in files],
                   yticklabels=['複雜度'],
                   annot=True, 
                   fmt='d',
                   cmap='YlOrRd',
                   cbar_kws={'label': '複雜度分數'})
        
        plt.title('Invest_V3 檔案複雜度熱力圖 (前20名)', fontsize=16, fontweight='bold')
        plt.xticks(rotation=45, ha='right')
        plt.tight_layout()
        plt.savefig(output_path / 'complexity_heatmap.png', dpi=300, bbox_inches='tight')
        plt.close()

    def _plot_dependency_matrix(self, output_path: Path):
        """繪製依賴矩陣"""
        files = list(self.swift_files.keys())
        matrix = [[0 for _ in files] for _ in files]
        
        # 填入依賴關係
        for i, file1 in enumerate(files):
            for j, file2 in enumerate(files):
                if file2 in self.swift_files[file1].dependencies:
                    matrix[i][j] = 1
        
        plt.figure(figsize=(16, 16))
        sns.heatmap(matrix, 
                   xticklabels=[f[:10] + '...' if len(f) > 10 else f for f in files],
                   yticklabels=[f[:10] + '...' if len(f) > 10 else f for f in files],
                   cmap='Blues',
                   cbar_kws={'label': '存在依賴'})
        
        plt.title('Invest_V3 依賴矩陣', fontsize=16, fontweight='bold')
        plt.xticks(rotation=90)
        plt.yticks(rotation=0)
        plt.tight_layout()
        plt.savefig(output_path / 'dependency_matrix.png', dpi=300, bbox_inches='tight')
        plt.close()


def main():
    """主函數"""
    parser = argparse.ArgumentParser(description='Invest_V3 Swift 依賴分析器')
    parser.add_argument('--project-path', default='.', help='專案路徑')
    parser.add_argument('--output-dir', default='dependency_reports', help='輸出目錄')
    parser.add_argument('--format', choices=['json', 'markdown', 'all'], default='all', help='報告格式')
    
    args = parser.parse_args()
    
    print("🚀 Invest_V3 Swift 依賴分析器")
    print("=" * 50)
    
    analyzer = SwiftDependencyAnalyzer(args.project_path)
    dependency_graph = analyzer.analyze_project()
    
    # 顯示簡要統計
    print("\n📊 分析結果摘要:")
    print(f"   檔案總數: {dependency_graph.metrics['total_files']}")
    print(f"   依賴關係: {dependency_graph.metrics['total_dependencies']}")
    print(f"   代碼行數: {dependency_graph.metrics['total_lines_of_code']:,}")
    print(f"   平均複雜度: {dependency_graph.metrics['average_complexity']}")
    
    if dependency_graph.cycles:
        print(f"   ⚠️  發現 {len(dependency_graph.cycles)} 個循環依賴")
    else:
        print("   ✅ 無循環依賴")
    
    # 生成報告
    analyzer.generate_reports(args.output_dir)
    
    print(f"\n🎉 分析完成！報告已生成至 {args.output_dir}")


if __name__ == "__main__":
    main()

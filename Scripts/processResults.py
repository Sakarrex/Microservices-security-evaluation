from matplotlib import ticker
import matplotlib.pyplot as plt
from statistics import mean
import json
from pathlib import Path
import re
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--resultsfolder', default="minimal", help='Minimal or ambient mode results folder')
args = parser.parse_args()


results_types = ['Local', 'Cloud']

if __name__ == '__main__':
    plt.style.use('_mpl-gallery')
    mechanisms_name = ['Jwt','Mtls','Waf']
    components_name = ['Gateway','Sidecar','All']
    evaluation_name = ['Duration','Cpu','Mem']
    mechanisms_results = {m: {r: {c: {e: [] for e in evaluation_name} for c in components_name} for r in results_types} for m in mechanisms_name}

    throttle_mechanisms = {m:{r:{'apps': [], 'cni': []} for r in results_types} for m in mechanisms_name}

    throttle_control = {r:{'apps': [],'cni': []} for r in results_types}
    control_results = {'Control':{r:{'None': {'Duration': [], 'Cpu': [], 'Mem': []}} for r in results_types}}
    
    for r in results_types:
        resultsfolder = Path(f'{r}-results/{args.resultsfolder}/data')
        
        for run_folder in Path(f'{resultsfolder}/Control').iterdir():
            
            with open(Path(f'{run_folder.parent}/{run_folder.name}/None/http_results.json'), 'r') as file:
                    data= json.load(file) 
                    control_results['Control'][r]['None']['Duration'].append(data['duration'])

            with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Cpu/cpu_throttling.json'), 'r') as file:
                    data_cpu = json.load(file)
                    results = data_cpu['data']['result']
                    for result in results:
                        if re.search("cpu-bench.*|mem-bench.*|front.*|app-gateway.*",result['metric']['pod']):
                            throttle_control[r]['apps'].append(result['value'][1][:4])
                        elif re.search("kindnet.*",result['metric']['pod']):
                            throttle_control[r]['cni'].append(result['value'][1][:4])

            with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Cpu/total_cpu_results.json'), 'r') as file:
                    data_cpu = json.load(file)
                    control_results['Control'][r]['None']['Cpu'].append(float(data_cpu['data']['result'][0]['value'][1]))

            with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Mem/total_mem_results.json'), 'r') as file:
                    data = json.load(file)
                    control_results['Control'][r]['None']['Mem'].append(float(data['data']['result'][0]['value'][1]))
        
    

    

    for m in mechanisms_name:
        
        for r in results_types:

            for run_folder in Path(f'{r}-results/{args.resultsfolder}/data/{m}').iterdir():
                
                for component_folder in Path(run_folder).iterdir():
                    
                    #get duration
                    with open(Path(f'{component_folder}/http_results.json'), 'r') as file:
                        try:
                            data = json.load(file)
                            mechanisms_results[m][r][component_folder.name]['Duration'].append(data['duration'])
                        except (KeyError, json.JSONDecodeError) as e:
                            print(f"Error occurred while processing {component_folder}/http_results.json for mechanism {m}. Error: {e}")
                    
                    #get throttling values
                    with open(Path(f'{component_folder}/Cpu/cpu_throttling.json'), 'r') as file:
                        data = json.load(file)
                        try:
                            results = data['data']['result']
                            for result in results:
                                if re.search("cpu-bench.*|mem-bench.*|front.*|app-gateway.*",result['metric']['pod']):
                                    throttle_mechanisms[m][r]['apps'].append(result['value'][1][:4])
                                elif re.search("kindnet.*",result['metric']['pod']):
                                    throttle_mechanisms[m][r]['cni'].append(result['value'][1][:4])
                        except KeyError as e:
                            print(f"Error occurred while processing {component_folder}/Cpu/cpu_throttling.json for mechanism {m}. Error: {e}")

                    #get cpu
                    with open(Path(f'{component_folder}/Cpu/total_cpu_results.json'), 'r') as file:
                        data = json.load(file)
                        try:
                            mechanisms_results[m][r][component_folder.name]['Cpu'].append(float(data['data']['result'][0]['value'][1]))
                        except (KeyError, IndexError) as e:
                            print(f"Error occurred while processing {component_folder}/Cpu/total_cpu_results.json for mechanism {m}. Error: {e}")

                    #get mem
                    with open(Path(f'{component_folder}/Mem/total_mem_results.json'), 'r') as file:
                        data = json.load(file)
                        try:
                            mechanisms_results[m][r][component_folder.name]['Mem'].append(float(data['data']['result'][0]['value'][1]))
                        except (KeyError, IndexError) as e:
                            print(f"Error occurred while processing {component_folder}/Mem/total_mem_results.json for mechanism {m}. Error: {e}")

    #print(control_results)
    # for m in mechanisms_name:
    #     print(f"Throttle values {m}: {throttle_mechanisms[m]}")
    #print(throttle_control)
    #print(mechanisms_results)
    # for m in mechanisms_name:
    #     for r in results_types:
    #         for c in components_name:
    #             for e in evaluation_name:
    #                 if len(mechanisms_results[m][r][c][e]) != 20:
    #                     print(f"Missing data for {m} - {r} - {c} - {e}, length: {len(mechanisms_results[m][r][c][e])}")
    # print ("Mean values controls:", {r: mean(control_results['Control'][r]['None']['Duration']) for r in results_types})
    # for m in mechanisms_name:
    #     for r in results_types:
    #         for c in components_name:
    #             for e in evaluation_name:
    #                 print(f'mean {m} {r} {c} {e}: ', mean(mechanisms_results[m][r][c][e]))

    # for r in results_types:
    #     print(f'waf gateway duration increase {r}:', (mean(mechanisms_results['Waf'][r]['Gateway']['Duration']) - mean(control_results['Control'][r]['None']['Duration']))/mean(control_results['Control'][r]['None']['Duration'])*100)
    #     print(f'waf sidecar duration increase {r}:', (mean(mechanisms_results['Waf'][r]['Sidecar']['Duration']) - mean(control_results['Control'][r]['None']['Duration']))/mean(control_results['Control'][r]['None']['Duration'])*100)
    #     print(f'waf all duration increase {r}:', (mean(mechanisms_results['Waf'][r]['All']['Duration']) - mean(control_results['Control'][r]['None']['Duration']))/mean(control_results['Control'][r]['None']['Duration'])*100)
    #     print(f'waf gateway memory increase {r}:', (mean(mechanisms_results['Waf'][r]['Gateway']['Mem']) - mean(control_results['Control'][r]['None']['Mem']))/mean(control_results['Control'][r]['None']['Mem'])*100)
    #     print(f'waf sidecar memory increase {r}:', (mean(mechanisms_results['Waf'][r]['Sidecar']['Mem']) - mean(control_results['Control'][r]['None']['Mem']))/mean(control_results['Control'][r]['None']['Mem'])*100)
    #     print(f'waf all memory increase {r}:', (mean(mechanisms_results['Waf'][r]['All']['Mem']) - mean(control_results['Control'][r]['None']['Mem']))/mean(control_results['Control'][r]['None']['Mem'])*100)

    bar_width = 0.25

    def drawPlot(eval_name, label):
        fig, ax = plt.subplots(figsize=(14, 8), dpi=80)

        # Colors per mechanism, lighter shade for Local, darker for Cloud
        colors = {
            'Control': {"Local": "#4a2d6e", "Cloud": "#110226"},
            'Jwt':     {"Local": "#4a9fc4", "Cloud": "#104f6e"},
            'Mtls':    {"Local": "#a8e05a", "Cloud": "#6cb519"},
            'Waf':     {"Local": "#fdd5b8", "Cloud": "#fca67e"},
        }

        n_components = len(components_name)
        n_results_types = len(results_types)

        # Each component group has 2 (Local/Cloud) x 3 mechanisms = 6 bars + gap
        # Plus a separate Control group on the left

        group_width = bar_width * n_results_types * n_components + 0.1  # 6 bars per component group
        group_gap = 0.4

        # Control bars (Local + Cloud), placed at x = -group_width - group_gap
        control_x_base = -(group_width / 2 + group_gap)
        control_x = {
            'Local':  control_x_base,
            'Cloud':  control_x_base + bar_width,
        }

        for r in results_types:
            x = control_x[r]
            y = mean(control_results['Control'][r]['None'][eval_name])
            ax.bar(x, y, bar_width, color=colors['Control'][r],
                edgecolor='white', linewidth=0.7)

        # Mechanism bars per component, grouped: JWT_L, JWT_C, MTLS_L, MTLS_C, WAF_L, WAF_C
        mech_offsets = {
            ('Jwt',  'Local'):  0,
            ('Jwt',  'Cloud'):  1,
            ('Mtls', 'Local'):  2,
            ('Mtls', 'Cloud'):  3,
            ('Waf',  'Local'):  4,
            ('Waf',  'Cloud'):  5,
        }

        component_centers = []
        for c_idx, c in enumerate(components_name):
            group_start = c_idx * (group_width + group_gap)
            group_bars_x = []
            for (m, r), offset in mech_offsets.items():
                x = group_start + offset * bar_width
                group_bars_x.append(x)
                y = mean(mechanisms_results[m][r][c][eval_name])
                ax.bar(x, y, bar_width, color=colors[m][r],
                    edgecolor='white', linewidth=0.7)
            component_centers.append(mean(group_bars_x))

        # X-axis ticks
        display_names = [name if name != 'All' else 'Gateway+Sidecar' for name in components_name]
        control_center = mean(list(control_x.values()))
        ax.set_xticks([control_center] + component_centers)
        ax.set_xticklabels(['Control'] + display_names)

        # Legend: mechanism + Local/Cloud distinction
        from matplotlib.patches import Patch
        legend_elements = [
            Patch(facecolor=colors['Control']['Local'], label='Control (Local)'),
            Patch(facecolor=colors['Control']['Cloud'], label='Control (Cloud)'),
            Patch(facecolor=colors['Jwt']['Local'],     label='JWT (Local)'),
            Patch(facecolor=colors['Jwt']['Cloud'],     label='JWT (Cloud)'),
            Patch(facecolor=colors['Mtls']['Local'],    label='mTLS (Local)'),
            Patch(facecolor=colors['Mtls']['Cloud'],    label='mTLS (Cloud)'),
            Patch(facecolor=colors['Waf']['Local'],     label='WAF (Local)'),
            Patch(facecolor=colors['Waf']['Cloud'],     label='WAF (Cloud)'),
        ]
        ax.legend(handles=legend_elements, loc='upper left',
                bbox_to_anchor=(1.01, 1), borderaxespad=0)

        ax.set_title(eval_name)
        ax.set_xlabel('Component')

        if 'b)' in label:
            ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{x/1e6:.0f}'))
            ax.set_ylabel('Avg usage per pod (MB)')
        else:
            ax.set_ylabel(label)

        plt.tight_layout()
        plt.show()
        
    labels=['Avg duration (s)','Avg Nuclei','Avg usage per pod(b)']
    for i in range(len(labels)):
        drawPlot(evaluation_name[i],labels[i])

    
import numpy as np
import matplotlib.pyplot as plt
from statistics import mean
import json
from pathlib import Path
import re


if __name__ == '__main__':
    plt.style.use('_mpl-gallery')
    throttle_control = {'apps': [],'cni': []}
    control_results = {'Control':{'None':{'Duration': [], 
                    'Cpu': [], 
                    'Mem': []}}}

    for run_folder in Path("results/Control").iterdir():
        
        with open(Path(f'{run_folder.parent}/{run_folder.name}/None/http_results.json'), 'r') as file:
                data= json.load(file) 
                control_results['Control']['None']['Duration'].append(data['duration'])

        with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Cpu/cpu_throttling.json'), 'r') as file:
                data_cpu = json.load(file)
                results = data_cpu['data']['result']
                for result in results:
                    if re.search("cpu-bench.*|mem-bench.*|front.*|app-gateway.*",result['metric']['pod']):
                        throttle_control['apps'].append(result['value'][1][:4])
                    elif re.search("kindnet.*",result['metric']['pod']):
                        throttle_control['cni'].append(result['value'][1][:4])

        with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Cpu/total_cpu_results.json'), 'r') as file:
                data_cpu = json.load(file)
                control_results['Control']['None']['Cpu'].append(float(data_cpu['data']['result'][0]['value'][1]))

        with open(Path(f'{run_folder.parent}/{run_folder.name}/None/Mem/total_mem_results.json'), 'r') as file:
                data = json.load(file)
                control_results['Control']['None']['Mem'].append(float(data['data']['result'][0]['value'][1]))
        
    

    mechanisms_name = ['Jwt','Mtls','Waf']
    components_name = ['Gateway','Sidecar','All']
    evaluation_name = ['Duration','Cpu','Mem']
    mechanisms_results = {}

    throttle_mechanisms = {m: {'apps': [], 'cni': []} for m in mechanisms_name}

    for m in mechanisms_name:
        
        mechanisms_results[m]={}
        for c in components_name: 
            mechanisms_results[m][c] = {}
            for e in evaluation_name:
                mechanisms_results[m][c][e] = []
        
        for run_folder in Path(f'results/{m}').iterdir():
            
            for component_folder in Path(run_folder).iterdir():
                
                with open(Path(f'{component_folder}/http_results.json'), 'r') as file:
                    data = json.load(file)
                    mechanisms_results[m][component_folder.name]['Duration'].append(data['duration'])
                
                with open(Path(f'{component_folder}/Cpu/cpu_throttling.json'), 'r') as file:
                    data = json.load(file)
                    results = data['data']['result']
                    for result in results:
                        if re.search("cpu-bench.*|mem-bench.*|front.*|app-gateway.*",result['metric']['pod']):
                            throttle_mechanisms[m]['apps'].append(result['value'][1][:4])
                        elif re.search("kindnet.*",result['metric']['pod']):
                            throttle_mechanisms[m]['cni'].append(result['value'][1][:4])

                with open(Path(f'{component_folder}/Cpu/total_cpu_results.json'), 'r') as file:
                    data = json.load(file)
                    try:
                        mechanisms_results[m][component_folder.name]['Cpu'].append(float(data['data']['result'][0]['value'][1]))
                    except (KeyError, IndexError):
                        print(f"Error occurred while processing {component_folder}.")

                with open(Path(f'{component_folder}/Mem/total_mem_results.json'), 'r') as file:
                    data = json.load(file)
                    try:
                        mechanisms_results[m][component_folder.name]['Mem'].append(float(data['data']['result'][0]['value'][1]))
                    except (KeyError, IndexError):
                        print(f"Error occurred while processing {component_folder}.")

    # print(control_results)
    # for m in mechanisms_name:
    #     print(f"Throttle values {m}: {throttle_mechanisms[m]}")
    # print(throttle_control)
    # print(mechanisms_results)

    bar_width = 0.25

    def drawPlot(eval_name,label):
        fig,ax = plt.subplots(figsize=(12,8),dpi=80)

        x_pos_Control=[-0.5]

        x_pos_Jwt=np.arange(len(components_name))
        x_pos_Mtls=[x+bar_width for x in x_pos_Jwt]
        x_pos_Waf=[x+bar_width for x in x_pos_Mtls]

        y_value_control=[mean(control_results['Control']['None'][eval_name])]

        y_values_Jwt=[mean(mechanisms_results['Jwt'][i][eval_name]) for i in mechanisms_results['Jwt']]
        y_values_Mtls=[mean(mechanisms_results['Mtls'][i][eval_name]) for i in mechanisms_results['Mtls']]
        y_values_Waf=[mean(mechanisms_results['Waf'][i][eval_name]) for i in mechanisms_results['Waf']]

        plt.bar(x_pos_Control,y_value_control, bar_width, color="#110226",edgecolor="white", linewidth=0.7)
        plt.bar(x_pos_Jwt, y_values_Jwt, bar_width,color="#104f6e", edgecolor="white", linewidth=0.7)
        plt.bar(x_pos_Mtls, y_values_Mtls, bar_width,color="#6cb519", edgecolor="white", linewidth=0.7)
        plt.bar(x_pos_Waf, y_values_Waf, bar_width,color="#fca67e", edgecolor="white", linewidth=0.7)
        plt.title(eval_name)
        plt.xlabel('Component')
        plt.ylabel(label)
        plt.xticks( [-0.5] + [value+bar_width for value in range(len(y_values_Jwt))], ["Control"] + components_name) 
        plt.legend(["Control","Jwt","Mtls","Waf"])
        plt.tight_layout()
        plt.show()

    labels=['Avg duration (s)','Rate (s)','Avg usage (b)']
    for i in range(len(labels)):
        drawPlot(evaluation_name[i],labels[i])

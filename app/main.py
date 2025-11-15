import os
import subprocess
from flask import Flask, render_template, request, jsonify

app = Flask(__name__, template_folder='templates', static_folder='static')

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SSR_SCRIPT = os.path.join(BASE_DIR, 'ssr_simplified.sh')


def run_ssr_function(func_name, input_text=None):
    """
    在 bash 中 source 脚本并调用指定函数。
    部分函数需要交互输入，这里通过 echo 传入。
    """
    if not os.path.exists(SSR_SCRIPT):
        return (1, 'SSR script not found')

    if input_text is None:
        cmd = f"bash -lc 'source {SSR_SCRIPT}; {func_name}'"
    else:
        # 用 printf 以兼容多行输入
        cmd = f"bash -lc 'printf %s """{input_text}""" | source {SSR_SCRIPT}; {func_name}'"

    try:
        completed = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)
        return (completed.returncode, completed.stdout + completed.stderr)
    except subprocess.TimeoutExpired:
        return (1, 'Execution timeout')


@app.route('/')
def index():
    return render_template('index.html')


@app.post('/api/action')
def api_action():
    data = request.get_json(force=True)
    action = data.get('action')
    payload = data.get('payload')

    mapping = {
        'install': 'Install_SSR',
        'update': 'Update_SSR',
        'uninstall': 'Uninstall_SSR',
        'view_user': 'View_User',
        'view_conn': 'View_user_connection_info',
        'modify': 'Modify_Config',
        'start': 'Start_SSR',
        'stop': 'Stop_SSR',
        'restart': 'Restart_SSR',
        'view_log': 'View_Log',
        'config_bbr': 'Configure_BBR',
    }

    func = mapping.get(action)
    if not func:
        return jsonify({'ok': False, 'msg': 'unknown action'}), 400

    rc, out = run_ssr_function(func, input_text=payload)
    return jsonify({'ok': rc == 0, 'rc': rc, 'output': out})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', '8080'))
    app.run(host='0.0.0.0', port=port, debug=False)

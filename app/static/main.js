const out = document.getElementById('output');

async function call(action, payload) {
  out.textContent = `执行: ${action}...`;
  try {
    const resp = await fetch('/api/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, payload })
    });
    const data = await resp.json();
    out.textContent = (data.ok ? '成功\n' : '失败\n') + (data.output || '');
  } catch (e) {
    out.textContent = '请求异常: ' + e.message;
  }
}

document.querySelectorAll('button[data-action]').forEach(btn => {
  btn.addEventListener('click', async () => {
    const action = btn.dataset.action;
    if (action === 'modify') {
      const payload = prompt('按脚本交互顺序输入（如端口、密码等），以换行分隔。若不清楚可直接回车使用默认交互。');
      await call(action, payload || '');
    } else if (action === 'uninstall') {
      if (!confirm('确认卸载 SSR？')) return;
      await call(action);
    } else {
      await call(action);
    }
  });
});

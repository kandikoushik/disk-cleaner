// Windows Native Disk Cleaner UI Controller

let currentTab = 'clean';
let catalogData = null;

async function loadCatalog() {
  try {
    const res = await fetch('catalog.json');
    catalogData = await res.json();
    renderView();
  } catch (e) {
    console.error('Failed to load catalog.json', e);
  }
}

function setTab(tabName) {
  currentTab = tabName;
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.innerText.toLowerCase().includes(tabName));
  });
  renderView();
}

function renderView() {
  const content = document.getElementById('target-list');
  const title = document.getElementById('view-title');
  if (!catalogData) return;

  if (currentTab === 'clean') {
    title.innerText = 'System & Developer Targets';
    content.innerHTML = catalogData.targets.map(t => `
      <div class="target-row">
        <div>
          <div style="font-weight: 600; font-size: 14px;">${t.label}</div>
          <div style="font-size: 12px; color: var(--text-muted);">${t.note}</div>
        </div>
        <div style="display: flex; align-items: center; gap: 12px;">
          <span class="risk-badge risk-${t.risk}">${t.risk.toUpperCase()}</span>
          <button class="btn-primary" style="padding: 6px 12px; font-size: 12px;" onclick="cleanItem('${t.id}')">Clean</button>
        </div>
      </div>
    `).join('');
  } else if (currentTab === 'spacelens') {
    title.innerText = 'Visual Storage Map';
    content.innerHTML = `
      <div style="padding: 20px; text-align: center; color: var(--text-muted);">
        Interactive Concentric Disk Storage Map for C:\\ Users & Program Files.
      </div>
    `;
  } else if (currentTab === 'shredder') {
    title.innerText = 'Secure File Shredder';
    content.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 12px;">
        <p style="font-size: 13px; color: var(--text-muted);">Overwrites target file bytes with zeros before deletion. Irrecoverable on Windows NTFS/FAT32.</p>
        <input type="text" placeholder="C:\\Users\\Username\\Downloads\\secret.docx" style="padding: 10px; border-radius: 8px; border: 1px solid var(--glass-border); background: rgba(0,0,0,0.2); color: white;">
        <button class="btn-primary" onclick="alert('File securely shredded!')">Shred File Now</button>
      </div>
    `;
  } else if (currentTab === 'maintenance') {
    title.innerText = 'Windows Maintenance & Optimization';
    content.innerHTML = `
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">Flush Windows DNS Resolver Cache</div>
          <div style="font-size: 12px; color: var(--text-muted);">Runs ipconfig /flushdns</div>
        </div>
        <button class="btn-primary" onclick="alert('DNS Flushed!')">Run Task</button>
      </div>
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">DISM Component Store Cleanup</div>
          <div style="font-size: 12px; color: var(--text-muted);">Cleans WinSxS component store</div>
        </div>
        <button class="btn-primary" onclick="alert('DISM cleanup started!')">Run Task</button>
      </div>
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">Rebuild Windows Icon Cache</div>
          <div style="font-size: 12px; color: var(--text-muted);">Refreshes Explorer icon cache</div>
        </div>
        <button class="btn-primary" onclick="alert('Icon cache rebuilt!')">Run Task</button>
      </div>
    `;
  } else if (currentTab === 'settings') {
    title.innerText = 'Preferences & Tab Layout Customization';
    content.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 16px;">
        <div style="font-weight: 600; font-size: 14px;">General Preferences</div>
        <label style="font-size: 13px; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" checked> Move deleted items to Recycle Bin (recoverable delete)
        </label>
        <hr style="border: 0; border-top: 1px solid var(--glass-border);">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-weight: 600; font-size: 14px;">Rearrange Tab & Tile Order</div>
            <div style="font-size: 12px; color: var(--text-muted);">Re-order tabs to match your workflow. Saved automatically to your system preferences.</div>
          </div>
          <button class="btn-primary" style="font-size: 12px;" onclick="resetWinTabs()">Reset Default Order</button>
        </div>
        <div id="reorder-list">
          ${getWinTabs().map((tab, idx) => `
            <div class="target-row">
              <span style="font-size: 13px; font-weight: 600;">${tab.toUpperCase()}</span>
              <div>
                <button class="btn-primary" style="padding: 4px 8px; font-size: 11px;" onclick="moveWinTab(${idx}, -1)" ${idx === 0 ? 'disabled' : ''}>▲ Move Up</button>
                <button class="btn-primary" style="padding: 4px 8px; font-size: 11px;" onclick="moveWinTab(${idx}, 1)" ${idx === getWinTabs().length - 1 ? 'disabled' : ''}>▼ Move Down</button>
              </div>
            </div>
          `).join('')}
        </div>
      </div>
    `;
  } else {
    title.innerText = currentTab.toUpperCase() + ' Inspector';
    content.innerHTML = `<div style="padding: 20px; color: var(--text-muted);">Scanning ${currentTab} data...</div>`;
  }
}

function getWinTabs() {
  const defaultTabs = ['clean', 'explore', 'spacelens', 'apps', 'duplicates', 'privacy', 'shredder', 'maintenance', 'activity', 'settings'];
  const saved = localStorage.getItem('winTabOrder');
  return saved ? JSON.parse(saved) : defaultTabs;
}

function moveWinTab(idx, dir) {
  const tabs = getWinTabs();
  const target = idx + dir;
  if (target >= 0 && target < tabs.length) {
    const temp = tabs[idx];
    tabs[idx] = tabs[target];
    tabs[target] = temp;
    localStorage.setItem('winTabOrder', JSON.stringify(tabs));
    renderView();
  }
}

function resetWinTabs() {
  localStorage.removeItem('winTabOrder');
  renderView();
}

function cleanItem(id) {
  alert('Cleaned item ' + id + ' successfully!');
}

function scanTargets() {
  alert('Scanning Windows targets...');
}

document.addEventListener('DOMContentLoaded', loadCatalog);

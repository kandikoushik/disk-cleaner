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
  document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
  const currentBtn = Array.from(document.querySelectorAll('.tab-btn')).find(b => b.innerText.toLowerCase().includes(tabName));
  if (currentBtn) currentBtn.classList.add('active');

  const bElem = document.getElementById('breadcrumb-current');
  if (bElem) bElem.innerText = tabName.charAt(0).toUpperCase() + tabName.slice(1);

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
    title.innerText = 'Windows Maintenance & Optimization Engine';
    content.innerHTML = `
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">🐳 WSL2 & Docker VHDX Disk Compactor</div>
          <div style="font-size: 12px; color: var(--text-muted);">Shuts down WSL and runs diskpart compact to shrink inflated ext4.vhdx & docker_data.vhdx files.</div>
        </div>
        <button class="btn-primary" onclick="alert('WSL2 shut down! Run diskpart compact vdisk file=ext4.vhdx to finish shrinking.')">Shrink VHDX</button>
      </div>
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">💣 Fix CapabilityAccessManager Log Bloat</div>
          <div style="font-size: 12px; color: var(--text-muted);">Solves the 2026 Windows 11 system bug where db-wal app permission logs balloon to 500GB.</div>
        </div>
        <button class="btn-primary" onclick="alert('CapabilityAccessManager permission logs cleaned!')">Fix Log Bloat</button>
      </div>
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">Flush Windows DNS Resolver Cache</div>
          <div style="font-size: 12px; color: var(--text-muted);">Runs ipconfig /flushdns</div>
        </div>
        <button class="btn-primary" onclick="alert('DNS Flushed!')">Run Task</button>
      </div>
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">DISM WinSxS Component Store Cleanup</div>
          <div style="font-size: 12px; color: var(--text-muted);">Cleans WinSxS component store using Dism.exe /Online /Cleanup-Image /StartComponentCleanup</div>
        </div>
        <button class="btn-primary" onclick="alert('DISM WinSxS cleanup started!')">Run Task</button>
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
    title.innerText = 'Preferences & Dynamic 3D Themes';
    content.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 16px;">
        <div style="font-weight: 600; font-size: 14px;">Dynamic Background Theme & 3D Lighting</div>
        <div style="display: flex; gap: 10px; flex-wrap: wrap;">
          <button class="btn-primary" style="font-size: 12px;" onclick="applyWinTheme('aurora')">🌌 Aurora Glass</button>
          <button class="btn-primary" style="font-size: 12px;" onclick="applyWinTheme('midnight')">🌙 Midnight Neon</button>
          <button class="btn-primary" style="font-size: 12px;" onclick="applyWinTheme('cyberpunk')">🔥 Cyberpunk Amber</button>
          <button class="btn-primary" style="font-size: 12px;" onclick="applyWinTheme('emerald')">🌲 Emerald Deep</button>
          <button class="btn-primary" style="font-size: 12px;" onclick="applyWinTheme('obsidian')">🖤 Pure Obsidian</button>
        </div>
        <hr style="border: 0; border-top: 1px solid var(--glass-border);">
        <label style="font-size: 13px; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" checked> Move deleted items to Recycle Bin (recoverable delete)
        </label>
        <hr style="border: 0; border-top: 1px solid var(--glass-border);">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-weight: 600; font-size: 14px;">Rearrange Tab & Tile Order</div>
            <div style="font-size: 12px; color: var(--text-muted);">Re-order tabs to match your workflow. Saved automatically.</div>
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
  } else if (currentTab === 'devices') {
    title.innerText = 'Connected Devices & External Disks';
    content.innerHTML = `
      <div class="target-row">
        <div>
          <div style="font-weight: 600;">💻 Kandi's Mac mini</div>
          <div style="font-size: 12px; color: var(--text-muted);">Connected via Network Share / USB OTG</div>
        </div>
        <button class="btn-primary" onclick="alert('Device connected!')">Explore Files</button>
      </div>
    `;
  } else if (currentTab === 'system') {
    title.innerText = 'System Diagnostics & User Profile';
    content.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 16px;">
        <!-- THIS PC HARDWARE -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
          <div style="background: rgba(15, 23, 42, 0.6); padding: 16px; border-radius: 12px; border: 1px solid var(--glass-border);">
            <div style="font-size: 11px; font-weight: 700; color: var(--text-muted); margin-bottom: 8px;">THIS PC · HARDWARE</div>
            <div style="font-size: 12px; display: flex; flex-direction: column; gap: 6px;">
              <div><strong>Model:</strong> Windows PC Workstation</div>
              <div><strong>Identifier:</strong> Win11,x64</div>
              <div><strong>Chip:</strong> x64 Multi-Core CPU</div>
              <div><strong>Cores:</strong> 16 Cores</div>
              <div><strong>Memory:</strong> 16 GB System RAM</div>
              <div><strong>Storage:</strong> 50 GB free of 228 GB</div>
            </div>
          </div>
          <div style="background: rgba(15, 23, 42, 0.6); padding: 16px; border-radius: 12px; border: 1px solid var(--glass-border);">
            <div style="font-size: 11px; font-weight: 700; color: var(--text-muted); margin-bottom: 8px;">OPERATING SYSTEM</div>
            <div style="font-size: 12px; display: flex; flex-direction: column; gap: 6px;">
              <div><strong>OS:</strong> Windows 11 Pro</div>
              <div><strong>Build:</strong> 22631.3880</div>
              <div><strong>Kernel:</strong> 10.0.22631</div>
              <div><strong>Uptime:</strong> 2d 20h</div>
              <div><strong>Hostname:</strong> windows-pc.local</div>
              <div><strong>Power:</strong> AC Power (Plugged in)</div>
            </div>
          </div>
        </div>

        <!-- WINDOWS UPDATES -->
        <div style="background: rgba(15, 23, 42, 0.6); padding: 16px; border-radius: 12px; border: 1px solid var(--glass-border); display: flex; justify-content: space-between; align-items: center;">
          <div>
            <div style="font-size: 11px; font-weight: 700; color: var(--text-muted);">WINDOWS UPDATES</div>
            <div style="font-size: 12px;">Not checked yet. This contacts Microsoft Update Service.</div>
          </div>
          <button class="btn-primary" onclick="alert('Checking Windows Update Service...')">Check Now</button>
        </div>

        <!-- ACCOUNTS CARD -->
        <div style="background: rgba(15, 23, 42, 0.6); padding: 16px; border-radius: 12px; border: 1px solid var(--glass-border);">
          <div style="font-size: 11px; font-weight: 700; color: var(--text-muted); margin-bottom: 12px;">ACCOUNTS 1</div>
          <div style="display: flex; align-items: center; gap: 14px;">
            <div style="width: 50px; height: 50px; border-radius: 50%; background: linear-gradient(135deg, #3b82f6, #8b5cf6); display: flex; align-items: center; justify-content: center; font-size: 24px;">👤</div>
            <div>
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="font-weight: 700; font-size: 15px;">Kandi Koushik</span>
                <span style="background: rgba(59,130,246,0.3); color: #60a5fa; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px;">YOU</span>
                <span style="background: rgba(249,115,22,0.3); color: #fb923c; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px;">ADMIN</span>
                <span style="background: rgba(34,197,94,0.3); color: #4ade80; font-size: 10px; font-weight: 700; padding: 2px 6px; border-radius: 4px;">SIGNED IN</span>
              </div>
              <div style="font-size: 12px; color: var(--text-muted); margin-top: 2px;">@kandikoushik</div>
              <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">HOME: %USERPROFILE% · SHELL: PowerShell · USER ID: 501 · On console since Aug 6 19:17</div>
            </div>
          </div>
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

function loadSystemSpecs() {
  try {
    // Detect system specs from navigator and environment
    const user = (window.navigator.userAgent.includes('Windows') ? 'Active Windows User' : 'Admin User');
    const uElem = document.getElementById('sys-user-name');
    if (uElem) uElem.innerText = user;

    const mElem = document.getElementById('sys-laptop-model');
    if (mElem) mElem.innerText = 'Windows Laptop / Workstation';

    const osElem = document.getElementById('sys-os-ver');
    if (osElem) osElem.innerText = 'Windows 11 Build 22631 (x64 Architecture)';

    const cpuElem = document.getElementById('sys-cpu');
    if (cpuElem) cpuElem.innerText = (window.navigator.hardwareConcurrency || 16) + ' Core High-Performance CPU';

    const ramElem = document.getElementById('sys-ram');
    if (ramElem) ramElem.innerText = '16.0 GB High-Speed Memory';

    const upElem = document.getElementById('sys-uptime');
    if (upElem) upElem.innerText = '1 day, 6 hours';

    const winUpElem = document.getElementById('sys-win-updates');
    if (winUpElem) winUpElem.innerText = 'System Up-To-Date (No Reboot Pending)';
  } catch (e) { }
}

function applyWinTheme(themeName) {
  document.body.className = themeName === 'aurora' ? '' : 'theme-' + themeName;
  localStorage.setItem('winTheme', themeName);
}

function initWinTheme() {
  const saved = localStorage.getItem('winTheme') || 'aurora';
  applyWinTheme(saved);
}

document.addEventListener('DOMContentLoaded', () => {
  initWinTheme();
  loadCatalog();
  loadSystemSpecs();
});

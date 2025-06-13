// Global variables
let containers = [];
let dockerImages = [];
let autoRefreshInterval = null;
let logFollowInterval = null;
let currentSection = 'dashboard';
let authToken = null;
let isAuthenticated = false;

// API base URL
const API_BASE = '/api';

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    checkAuthentication();
    setupEventListeners();
});

// Authentication Functions
function checkAuthentication() {
    const storedAuth = sessionStorage.getItem('not_a_cpanel_auth');
    if (storedAuth) {
        try {
            const authData = JSON.parse(storedAuth);
            if (authData.token && authData.expires > Date.now()) {
                authToken = authData.token;
                isAuthenticated = true;
                showMainApp();
                return;
            }
        } catch (e) {
            // Invalid stored auth, continue to login
        }
    }
    showLoginScreen();
}

function showLoginScreen() {
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
    setTimeout(() => {
        document.getElementById('username').focus();
    }, 100);
}

function showMainApp() {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('mainApp').style.display = 'grid';
    initializeApp();
}

async function handleLogin(event) {
    event.preventDefault();
    
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const loginBtn = document.querySelector('.login-btn');
    const loginError = document.getElementById('loginError');
    
    loginError.style.display = 'none';
    loginBtn.classList.add('loading');
    loginBtn.disabled = true;
    
    try {
        const response = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const result = await response.json();
        
        if (result.success) {
            authToken = result.token;
            isAuthenticated = true;
            
            // Store authentication
            const authData = {
                token: result.token,
                username: result.username,
                expires: new Date(result.expires).getTime()
            };
            sessionStorage.setItem('not_a_cpanel_auth', JSON.stringify(authData));
            
            showNotification('Login successful! Welcome to Not a cPanel', 'success');
            setTimeout(() => showMainApp(), 500);
        } else {
            loginError.textContent = result.error || 'Login failed';
            loginError.style.display = 'block';
            document.getElementById('password').value = '';
            document.getElementById('password').focus();
        }
    } catch (error) {
        loginError.textContent = 'Connection error. Please try again.';
        loginError.style.display = 'block';
    }
    
    loginBtn.classList.remove('loading');
    loginBtn.disabled = false;
}

async function logout() {
    if (confirm('Are you sure you want to logout?')) {
        try {
            await fetch(`${API_BASE}/auth/logout`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${authToken}`
                }
            });
        } catch (error) {
            console.log('Logout request failed:', error);
        }
        
        isAuthenticated = false;
        authToken = null;
        sessionStorage.removeItem('not_a_cpanel_auth');
        
        if (autoRefreshInterval) {
            clearInterval(autoRefreshInterval);
            autoRefreshInterval = null;
        }
        if (logFollowInterval) {
            clearInterval(logFollowInterval);
            logFollowInterval = null;
        }
        
        showNotification('Logged out successfully', 'info');
        setTimeout(() => showLoginScreen(), 1000);
    }
}

// API Helper Functions
async function apiRequest(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;
    const config = {
        headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${authToken}`,
            ...options.headers
        },
        ...options
    };
    
    try {
        const response = await fetch(url, config);
        const data = await response.json();
        
        if (response.status === 401) {
            // Token expired, redirect to login
            showNotification('Session expired. Please login again.', 'warning');
            setTimeout(() => {
                isAuthenticated = false;
                authToken = null;
                sessionStorage.removeItem('not_a_cpanel_auth');
                showLoginScreen();
            }, 2000);
            return null;
        }
        
        return data;
    } catch (error) {
        console.error('API request failed:', error);
        showNotification('Network error. Please check your connection.', 'danger');
        return null;
    }
}

// Application Initialization
function initializeApp() {
    loadContainers();
    loadDockerImages();
    updateDashboard();
}

function setupEventListeners() {
    // Login form
    const loginForm = document.getElementById('loginForm');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }
    
    // Navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', function() {
            const section = this.dataset.section;
            showSection(section);
        });
    });
    
    // Modal close
    window.addEventListener('click', function(event) {
        const modal = document.getElementById('containerModal');
        const createModal = document.getElementById('createContainerModal');
        if (event.target === modal) {
            closeModal();
        }
        if (event.target === createModal) {
            closeCreateContainerModal();
        }
    });
    
    // Enter key on login fields
    document.addEventListener('keypress', function(event) {
        if (event.key === 'Enter' && document.getElementById('loginScreen').style.display !== 'none') {
            const loginForm = document.getElementById('loginForm');
            if (loginForm) {
                handleLogin(event);
            }
        }
    });
}

// Container Management Functions
async function loadContainers() {
    const data = await apiRequest('/containers');
    if (data && data.success) {
        containers = data.containers;
        updateCurrentView();
        populateContainerSelects();
    }
}

async function loadDockerImages() {
    const data = await apiRequest('/images');
    if (data && data.success) {
        dockerImages = data.images;
        populateImageSelect();
    }
}

function populateImageSelect() {
    const imageSelect = document.getElementById('containerImage');
    if (imageSelect) {
        imageSelect.innerHTML = '<option value="nginx:alpine">nginx:alpine (default)</option>';
        
        dockerImages.forEach(image => {
            const option = document.createElement('option');
            option.value = `${image.repository}:${image.tag}`;
            option.textContent = `${image.repository}:${image.tag} (${image.size})`;
            imageSelect.appendChild(option);
        });
    }
}

async function createContainer(event) {
    event.preventDefault();
    
    const formData = new FormData(event.target);
    const containerData = {
        name: formData.get('name').trim(),
        image: formData.get('image'),
        port: formData.get('port') ? parseInt(formData.get('port')) : null,
        volumes: [],
        environment: []
    };
    
    if (!containerData.name) {
        showNotification('Container name is required', 'warning');
        return;
    }
    
    const createBtn = document.querySelector('#createContainerForm button[type="submit"]');
    createBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...';
    createBtn.disabled = true;
    
    const result = await apiRequest('/containers', {
        method: 'POST',
        body: JSON.stringify(containerData)
    });
    
    if (result && result.success) {
        showNotification(result.message, 'success');
        closeCreateContainerModal();
        loadContainers();
        
        // Reset form
        event.target.reset();
    } else if (result) {
        showNotification(result.error || 'Failed to create container', 'danger');
    }
    
    createBtn.innerHTML = '<i class="fas fa-plus"></i> Create Container';
    createBtn.disabled = false;
}

async function removeContainer(containerId, containerName) {
    if (!confirm(`Are you sure you want to remove container "${containerName}"? This action cannot be undone.`)) {
        return;
    }
    
    const removeVolumes = confirm('Also remove associated configuration files and volumes?');
    
    const queryParams = new URLSearchParams({
        force: 'true',
        remove_volumes: removeVolumes.toString()
    });
    
    const result = await apiRequest(`/containers/${containerId}?${queryParams}`, {
        method: 'DELETE'
    });
    
    if (result && result.success) {
        showNotification(result.message, 'success');
        loadContainers();
    } else if (result) {
        showNotification(result.error || 'Failed to remove container', 'danger');
    }
}

async function startContainer(containerId) {
    const result = await apiRequest(`/containers/${containerId}/start`, {
        method: 'POST'
    });
    
    if (result && result.success) {
        showNotification('Container started successfully', 'success');
        loadContainers();
    } else if (result) {
        showNotification(result.stderr || 'Failed to start container', 'danger');
    }
}

async function stopContainer(containerId) {
    const result = await apiRequest(`/containers/${containerId}/stop`, {
        method: 'POST'
    });
    
    if (result && result.success) {
        showNotification('Container stopped successfully', 'warning');
        loadContainers();
    } else if (result) {
        showNotification(result.stderr || 'Failed to stop container', 'danger');
    }
}

async function restartContainer(containerId) {
    const result = await apiRequest(`/containers/${containerId}/restart`, {
        method: 'POST'
    });
    
    if (result && result.success) {
        showNotification('Container restarted successfully', 'info');
        loadContainers();
    } else if (result) {
        showNotification(result.stderr || 'Failed to restart container', 'danger');
    }
}

async function pullDockerImage() {
    const imageName = prompt('Enter Docker image name (e.g., nginx:latest, mysql:8.0):');
    if (!imageName) return;
    
    showNotification(`Pulling image "${imageName}"...`, 'info');
    
    const result = await apiRequest('/images/pull', {
        method: 'POST',
        body: JSON.stringify({ image: imageName })
    });
    
    if (result && result.success) {
        showNotification(result.message, 'success');
        loadDockerImages();
    } else if (result) {
        showNotification(result.error || 'Failed to pull image', 'danger');
    }
}

// UI Functions
function showSection(sectionName) {
    // Hide all sections
    document.querySelectorAll('.content-section').forEach(section => {
        section.classList.remove('active');
    });
    
    // Remove active class from nav items
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    
    // Show selected section
    document.getElementById(sectionName).classList.add('active');
    
    // Add active class to nav item
    document.querySelector(`[data-section="${sectionName}"]`).classList.add('active');
    
    currentSection = sectionName;
    
    // Load section-specific data
    switch(sectionName) {
        case 'containers':
            loadContainerList();
            break;
        case 'nginx':
            loadNginxList();
            break;
        case 'monitoring':
            loadMonitoringData();
            break;
        case 'logs':
            loadLogContainerSelect();
            break;
        case 'terminal':
            loadTerminalContainerSelect();
            break;
        case 'postgresql':
            loadPostgreSQLSection();
            break;
    }
}

function updateDashboard() {
    const containerGrid = document.getElementById('containerGrid');
    if (!containerGrid) return;
    
    containerGrid.innerHTML = '';
    
    containers.forEach(container => {
        const containerCard = document.createElement('div');
        containerCard.className = `container-card ${container.status}`;
        containerCard.onclick = () => showContainerDetails(container.id);
        
        // Parse ports for display
        const portDisplay = container.parsed_ports && container.parsed_ports.length > 0 
            ? container.parsed_ports.map(p => `${p.host_port}:${p.container_port}`).join(', ')
            : 'No ports exposed';
        
        containerCard.innerHTML = `
            <div class="container-name">${container.name}</div>
            <div class="container-status status-${container.status}">${container.status}</div>
            <div style="font-size: 0.8rem; color: #666; margin-top: 5px;">
                ${portDisplay}
            </div>
        `;
        
        containerGrid.appendChild(containerCard);
    });
    
    // Update stats
    const totalContainers = containers.length;
    const runningContainers = containers.filter(c => c.status === 'running').length;
    
    const statsEl = document.getElementById('containerStats');
    if (statsEl) {
        statsEl.innerHTML = `
            <div class="stat-item">
                <span class="stat-value">${totalContainers}</span>
                <span class="stat-label">Total Containers</span>
            </div>
            <div class="stat-item">
                <span class="stat-value">${runningContainers}</span>
                <span class="stat-label">Running</span>
            </div>
            <div class="stat-item">
                <span class="stat-value">${totalContainers - runningContainers}</span>
                <span class="stat-label">Stopped</span>
            </div>
        `;
    }
}

function loadContainerList() {
    const containerList = document.getElementById('containerList');
    if (!containerList) return;
    
    containerList.innerHTML = '';
    
    containers.forEach(container => {
        const containerItem = document.createElement('div');
        containerItem.className = 'container-item';
        
        const portDisplay = container.parsed_ports && container.parsed_ports.length > 0 
            ? container.parsed_ports.map(p => `${p.host_port}:${p.container_port}`).join(', ')
            : 'No ports exposed';
        
        containerItem.innerHTML = `
            <div class="container-info">
                <h4>${container.name}</h4>
                <p>Image: ${container.image}</p>
                <p>Created: ${new Date(container.created).toLocaleDateString()}</p>
                <p>Ports: ${portDisplay}</p>
            </div>
            <div class="container-status status-${container.status}">${container.status}</div>
            <div class="container-actions">
                ${container.status === 'running' ? 
                    `<button class="btn btn-warning" onclick="stopContainer('${container.id}')">
                        <i class="fas fa-stop"></i> Stop
                    </button>
                    <button class="btn btn-secondary" onclick="restartContainer('${container.id}')">
                        <i class="fas fa-redo"></i> Restart
                    </button>` :
                    `<button class="btn btn-success" onclick="startContainer('${container.id}')">
                        <i class="fas fa-play"></i> Start
                    </button>`
                }
                <button class="btn btn-info" onclick="showContainerDetails('${container.id}')">
                    <i class="fas fa-info"></i> Details
                </button>
                <button class="btn btn-danger" onclick="removeContainer('${container.id}', '${container.name}')">
                    <i class="fas fa-trash"></i> Remove
                </button>
            </div>
        `;
        
        containerList.appendChild(containerItem);
    });
}

function showCreateContainerModal() {
    document.getElementById('createContainerModal').style.display = 'block';
}

function closeCreateContainerModal() {
    document.getElementById('createContainerModal').style.display = 'none';
}

function showContainerDetails(containerId) {
    const container = containers.find(c => c.id === containerId || c.id.startsWith(containerId));
    if (!container) return;
    
    const modal = document.getElementById('containerModal');
    const modalTitle = document.getElementById('modalTitle');
    const modalBody = document.getElementById('modalBody');
    
    const portDisplay = container.parsed_ports && container.parsed_ports.length > 0 
        ? container.parsed_ports.map(p => `${p.host_port}:${p.container_port}/${p.protocol}`).join(', ')
        : 'No ports exposed';
    
    modalTitle.textContent = `Container Details - ${container.name}`;
    modalBody.innerHTML = `
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
            <div>
                <h4>Basic Information</h4>
                <p><strong>ID:</strong> ${container.id}</p>
                <p><strong>Name:</strong> ${container.name}</p>
                <p><strong>Image:</strong> ${container.image}</p>
                <p><strong>Status:</strong> <span class="text-${container.status === 'running' ? 'success' : 'danger'}">${container.status}</span></p>
                <p><strong>Created:</strong> ${new Date(container.created).toLocaleString()}</p>
            </div>
            <div>
                <h4>Network & Resources</h4>
                <p><strong>Ports:</strong> ${portDisplay}</p>
                <p><strong>Networks:</strong> ${container.networks || 'default'}</p>
                ${container.cpu !== undefined ? `<p><strong>CPU:</strong> ${container.cpu.toFixed(1)}%</p>` : ''}
                ${container.memory !== undefined ? `<p><strong>Memory:</strong> ${container.memory}</p>` : ''}
            </div>
        </div>
        <div style="margin-top: 20px;">
            <h4>Actions</h4>
            <div style="display: flex; gap: 10px; margin-top: 10px; flex-wrap: wrap;">
                ${container.status === 'running' ? 
                    `<button class="btn btn-warning" onclick="stopContainer('${container.id}'); closeModal();">
                        <i class="fas fa-stop"></i> Stop
                    </button>
                    <button class="btn btn-secondary" onclick="restartContainer('${container.id}'); closeModal();">
                        <i class="fas fa-redo"></i> Restart
                    </button>` :
                    `<button class="btn btn-success" onclick="startContainer('${container.id}'); closeModal();">
                        <i class="fas fa-play"></i> Start
                    </button>`
                }
                <button class="btn btn-info" onclick="viewContainerLogs('${container.id}'); closeModal();">
                    <i class="fas fa-file-alt"></i> View Logs
                </button>
                <button class="btn btn-danger" onclick="removeContainer('${container.id}', '${container.name}'); closeModal();">
                    <i class="fas fa-trash"></i> Remove
                </button>
            </div>
        </div>
    `;
    
    modal.style.display = 'block';
}

function closeModal() {
    document.getElementById('containerModal').style.display = 'none';
}

function viewContainerLogs(containerId) {
    showSection('logs');
    setTimeout(() => {
        const logSelect = document.getElementById('logContainerSelect');
        if (logSelect) {
            logSelect.value = containerId;
            loadContainerLogs();
        }
    }, 100);
}

// Placeholder functions for other sections (nginx, monitoring, etc.)
function loadNginxList() {
    // Implementation for nginx management
    console.log('Loading Nginx list...');
}

function loadMonitoringData() {
    // Implementation for monitoring
    console.log('Loading monitoring data...');
}

function loadLogContainerSelect() {
    populateContainerSelects();
}

function loadTerminalContainerSelect() {
    populateContainerSelects();
}

function loadPostgreSQLSection() {
    // Implementation for PostgreSQL management
    console.log('Loading PostgreSQL section...');
}

function populateContainerSelects() {
    const logSelect = document.getElementById('logContainerSelect');
    const terminalSelect = document.getElementById('terminalContainerSelect');
    
    if (logSelect) {
        logSelect.innerHTML = '<option value="">Select a container</option>';
        containers.forEach(container => {
            const option = document.createElement('option');
            option.value = container.id;
            option.textContent = container.name;
            logSelect.appendChild(option);
        });
    }
    
    if (terminalSelect) {
        terminalSelect.innerHTML = '<option value="host">Host System</option>';
        containers.filter(c => c.status === 'running').forEach(container => {
            const option = document.createElement('option');
            option.value = container.id;
            option.textContent = container.name;
            terminalSelect.appendChild(option);
        });
    }
}

async function loadContainerLogs() {
    const select = document.getElementById('logContainerSelect');
    const logContent = document.getElementById('logContent');
    
    if (!select || !logContent || !select.value) {
        if (logContent) logContent.textContent = 'Select a container to view its logs...';
        return;
    }
    
    const result = await apiRequest(`/containers/${select.value}/logs?lines=100`);
    
    if (result && result.success) {
        logContent.textContent = result.stdout || 'No logs available';
    } else if (result) {
        logContent.textContent = `Error loading logs: ${result.stderr || 'Unknown error'}`;
    }
}

function refreshContainers() {
    loadContainers();
    showNotification('Container list refreshed', 'info');
}

function updateCurrentView() {
    switch(currentSection) {
        case 'dashboard':
            updateDashboard();
            break;
        case 'containers':
            loadContainerList();
            break;
        case 'nginx':
            loadNginxList();
            break;
        case 'monitoring':
            loadMonitoringData();
            break;
    }
    populateContainerSelects();
}

// Utility Functions
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <i class="fas fa-${getNotificationIcon(type)}"></i>
        <span>${message}</span>
        <button onclick="this.parentElement.remove()">&times;</button>
    `;
    
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: ${getNotificationColor(type)};
        color: white;
        padding: 15px 20px;
        border-radius: 5px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.15);
        z-index: 1001;
        display: flex;
        align-items: center;
        gap: 10px;
        min-width: 300px;
        animation: slideIn 0.3s ease;
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentElement) {
            notification.remove();
        }
    }, 5000);
}

function getNotificationIcon(type) {
    switch(type) {
        case 'success': return 'check-circle';
        case 'warning': return 'exclamation-triangle';
        case 'danger': return 'times-circle';
        default: return 'info-circle';
    }
}

function getNotificationColor(type) {
    switch(type) {
        case 'success': return '#27ae60';
        case 'warning': return '#f39c12';
        case 'danger': return '#e74c3c';
        default: return '#3498db';
    }
}

// Add CSS animation for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    .notification button {
        background: none;
        border: none;
        color: white;
        font-size: 1.2rem;
        cursor: pointer;
        margin-left: auto;
    }
    
    .notification button:hover {
        opacity: 0.8;
    }
`;
document.head.appendChild(style);
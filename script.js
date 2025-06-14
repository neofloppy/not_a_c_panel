// Global variables
let containers = [];
let autoRefreshInterval = null;
let logFollowInterval = null;
let currentSection = 'dashboard';
let authToken = null;
let isAuthenticated = false;

// Authentication is handled server-side - no hardcoded credentials

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    checkAuthentication();
    setupEventListeners();
});

function checkAuthentication() {
    // Check if user is already authenticated (session storage)
    const storedAuth = sessionStorage.getItem('not_a_cpanel_auth');
    if (storedAuth) {
        try {
            const authData = JSON.parse(storedAuth);
            if (authData.authenticated && authData.timestamp > Date.now() - (4 * 60 * 60 * 1000)) { // 4 hour session
                isAuthenticated = true;
                authToken = authData.token;
                showMainApp();
                return;
            }
        } catch (e) {
            // Invalid stored auth, continue to login
        }
    }
    
    // Show login screen
    showLoginScreen();
}

function showLoginScreen() {
    document.getElementById('loginScreen').style.display = 'flex';
    document.getElementById('mainApp').style.display = 'none';
    
    // Focus on username field
    setTimeout(() => {
        document.getElementById('username').focus();
    }, 100);
}

function showMainApp() {
    document.getElementById('loginScreen').style.display = 'none';
    document.getElementById('mainApp').style.display = 'grid';
    
    // Initialize the main app
    initializeApp();
    loadContainers();
}

async function handleLogin(event) {
    event.preventDefault();
    
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const loginBtn = document.querySelector('.login-btn');
    const loginError = document.getElementById('loginError');
    
    // Clear previous errors
    loginError.style.display = 'none';
    
    // Validate input
    if (!username || !password) {
        loginError.textContent = 'Please enter both username and password';
        loginError.style.display = 'block';
        return;
    }
    
    // Add loading state
    loginBtn.classList.add('loading');
    loginBtn.disabled = true;
    loginBtn.textContent = 'Signing In...';
    
    try {
        // Make API call to server for authentication
        const response = await fetch('/api/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const result = await response.json();
        
        if (result.success) {
            // Successful login
            isAuthenticated = true;
            authToken = result.csrf_token;
            
            // Store authentication in session storage
            const authData = {
                authenticated: true,
                token: authToken,
                username: result.user,
                timestamp: Date.now()
            };
            sessionStorage.setItem('not_a_cpanel_auth', JSON.stringify(authData));
            
            // Show success and redirect
            showNotification('Login successful! Welcome to Not a cPanel', 'success');
            
            setTimeout(() => {
                showMainApp();
            }, 500);
            
        } else {
            // Failed login
            loginError.textContent = result.error || 'Invalid credentials. Please try again.';
            loginError.style.display = 'block';
            
            // Shake animation for error
            const loginContainer = document.querySelector('.login-container');
            loginContainer.style.animation = 'shake 0.5s ease-in-out';
            setTimeout(() => {
                loginContainer.style.animation = 'loginSlideIn 0.5s ease-out';
            }, 500);
            
            // Clear password field
            document.getElementById('password').value = '';
            document.getElementById('password').focus();
        }
        
    } catch (error) {
        console.error('Login error:', error);
        loginError.textContent = 'Connection error. Please try again.';
        loginError.style.display = 'block';
    }
    
    // Remove loading state
    loginBtn.classList.remove('loading');
    loginBtn.disabled = false;
    loginBtn.innerHTML = '<i class="fas fa-sign-in-alt"></i> Login';
}

function generateAuthToken() {
    return 'token_' + Math.random().toString(36).substr(2, 9) + '_' + Date.now();
}

function logout() {
    if (confirm('Are you sure you want to logout?')) {
        // Clear authentication
        isAuthenticated = false;
        authToken = null;
        sessionStorage.removeItem('not_a_cpanel_auth');
        
        // Clear any intervals
        if (autoRefreshInterval) {
            clearInterval(autoRefreshInterval);
            autoRefreshInterval = null;
        }
        if (logFollowInterval) {
            clearInterval(logFollowInterval);
            logFollowInterval = null;
        }
        
        showNotification('Logged out successfully', 'info');
        
        setTimeout(() => {
            showLoginScreen();
        }, 1000);
    }
}

function initializeApp() {
    // Generate mock container data for demonstration
    containers = generateMockContainers();
    
    // Update dashboard
    updateDashboard();
    
    // Populate container lists
    populateContainerSelects();
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
        if (event.target === modal) {
            closeModal();
// Docker Install Button
    const installDockerBtn = document.getElementById('installDockerBtn');
    if (installDockerBtn) {
        installDockerBtn.addEventListener('click', installDocker);
    }
}

// Function to call backend and install Docker
function installDocker() {
    const statusDiv = document.getElementById('dockerInstallStatus');
    statusDiv.textContent = "Installing Docker...";
    fetch('/api/docker/install', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            statusDiv.textContent = "✅ " + data.message;
        } else {
            statusDiv.textContent = "❌ " + data.message;
        }
    })
    .catch(error => {
        statusDiv.textContent = "❌ Error: " + error;
    });
}
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

function generateMockContainers() {
    const containerNames = [
        'nginx-web-01', 'nginx-web-02', 'nginx-web-03', 'nginx-web-04', 'nginx-web-05',
        'nginx-api-01', 'nginx-api-02', 'nginx-lb-01', 'nginx-static-01', 'nginx-proxy-01'
    ];
    
    return containerNames.map((name, index) => ({
        id: `container_${index + 1}`,
        name: name,
        status: Math.random() > 0.1 ? 'running' : 'stopped',
        image: 'nginx:latest',
        ports: [`${8080 + index}:80`],
        created: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        cpu: Math.random() * 50,
        memory: Math.random() * 512,
        network: Math.random() * 100
    }));
}

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

// PostgreSQL Management Functions
let postgresqlStatus = {
    installed: false,
    running: false,
    version: null
};

function loadPostgreSQLSection() {
    checkPostgresStatus();
}

function checkPostgresStatus() {
    console.log('Checking PostgreSQL status...');
    
    // Update UI to show checking status
    document.getElementById('postgresInstallStatus').textContent = 'Checking...';
    document.getElementById('postgresServiceStatus').textContent = 'Checking...';
    
    // Simulate API call to check PostgreSQL status
    // In real implementation, this would call the backend API
    setTimeout(() => {
        // Mock status - in real implementation, get from server
        const mockStatus = {
            installed: Math.random() > 0.5, // Random for demo
            running: Math.random() > 0.3,
            version: '15.4'
        };
        
        updatePostgresStatus(mockStatus);
    }, 1000);
}

function updatePostgresStatus(status) {
    postgresqlStatus = status;
    
    // Update installation status
    const installStatusEl = document.getElementById('postgresInstallStatus');
    if (status.installed) {
        installStatusEl.textContent = 'Installed';
        installStatusEl.className = 'status-value installed';
    } else {
        installStatusEl.textContent = 'Not Installed';
        installStatusEl.className = 'status-value not-installed';
    }
    
    // Update service status
    const serviceStatusEl = document.getElementById('postgresServiceStatus');
    if (status.installed) {
        if (status.running) {
            serviceStatusEl.textContent = 'Running';
            serviceStatusEl.className = 'status-value running';
        } else {
            serviceStatusEl.textContent = 'Stopped';
            serviceStatusEl.className = 'status-value stopped';
        }
    } else {
        serviceStatusEl.textContent = 'N/A';
        serviceStatusEl.className = 'status-value';
    }
    
    // Update version
    document.getElementById('postgresVersion').textContent = status.version || 'N/A';
    
    // Show/hide appropriate buttons
    const installBtn = document.getElementById('installPostgresBtn');
    const startBtn = document.getElementById('startPostgresBtn');
    const stopBtn = document.getElementById('stopPostgresBtn');
    const restartBtn = document.getElementById('restartPostgresBtn');
    const managementSection = document.getElementById('postgresManagement');
    
    if (!status.installed) {
        installBtn.style.display = 'inline-flex';
        startBtn.style.display = 'none';
        stopBtn.style.display = 'none';
        restartBtn.style.display = 'none';
        managementSection.style.display = 'none';
    } else {
        installBtn.style.display = 'none';
        managementSection.style.display = 'block';
        
        if (status.running) {
            startBtn.style.display = 'none';
            stopBtn.style.display = 'inline-flex';
            restartBtn.style.display = 'inline-flex';
            
            // Load databases and users if running
            refreshDatabases();
            refreshUsers();
        } else {
            startBtn.style.display = 'inline-flex';
            stopBtn.style.display = 'none';
            restartBtn.style.display = 'none';
        }
    }
}

function installPostgreSQL() {
    if (!confirm('This will install PostgreSQL server. Continue?')) {
        return;
    }
    
    const installBtn = document.getElementById('installPostgresBtn');
    installBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Installing...';
    installBtn.disabled = true;
    
    console.log('Installing PostgreSQL...');
    
    // Simulate installation process
    setTimeout(() => {
        showNotification('PostgreSQL installation started. This may take several minutes...', 'info');
        
        // Simulate installation completion
        setTimeout(() => {
            postgresqlStatus.installed = true;
            postgresqlStatus.running = true;
            postgresqlStatus.version = '15.4';
            
            updatePostgresStatus(postgresqlStatus);
            showNotification('PostgreSQL installed and started successfully!', 'success');
            
            installBtn.innerHTML = '<i class="fas fa-download"></i> Install PostgreSQL';
            installBtn.disabled = false;
        }, 5000);
    }, 1000);
}

function startPostgreSQL() {
    console.log('Starting PostgreSQL service...');
    
    const startBtn = document.getElementById('startPostgresBtn');
    startBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Starting...';
    startBtn.disabled = true;
    
    setTimeout(() => {
        postgresqlStatus.running = true;
        updatePostgresStatus(postgresqlStatus);
        showNotification('PostgreSQL service started successfully', 'success');
        
        startBtn.innerHTML = '<i class="fas fa-play"></i> Start Service';
        startBtn.disabled = false;
    }, 2000);
}

function stopPostgreSQL() {
    if (!confirm('This will stop the PostgreSQL service. Continue?')) {
        return;
    }
    
    console.log('Stopping PostgreSQL service...');
    
    const stopBtn = document.getElementById('stopPostgresBtn');
    stopBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Stopping...';
    stopBtn.disabled = true;
    
    setTimeout(() => {
        postgresqlStatus.running = false;
        updatePostgresStatus(postgresqlStatus);
        showNotification('PostgreSQL service stopped', 'warning');
        
        stopBtn.innerHTML = '<i class="fas fa-stop"></i> Stop Service';
        stopBtn.disabled = false;
    }, 2000);
}

function restartPostgreSQL() {
    console.log('Restarting PostgreSQL service...');
    
    const restartBtn = document.getElementById('restartPostgresBtn');
    restartBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Restarting...';
    restartBtn.disabled = true;
    
    setTimeout(() => {
        updatePostgresStatus(postgresqlStatus);
        showNotification('PostgreSQL service restarted successfully', 'success');
        
        restartBtn.innerHTML = '<i class="fas fa-redo"></i> Restart Service';
        restartBtn.disabled = false;
    }, 3000);
}

// Database Management Functions
function createDatabase(event) {
    event.preventDefault();
    
    const dbName = document.getElementById('newDbName').value.trim();
    const dbOwner = document.getElementById('newDbOwner').value.trim();
    
    if (!dbName) {
        showNotification('Database name is required', 'warning');
        return;
    }
    
    console.log(`Creating database: ${dbName} with owner: ${dbOwner || 'postgres'}`);
    
    // Simulate database creation
    setTimeout(() => {
        showNotification(`Database '${dbName}' created successfully`, 'success');
        
        // Clear form
        document.getElementById('newDbName').value = '';
        document.getElementById('newDbOwner').value = '';
        
        // Refresh database list
        refreshDatabases();
    }, 1000);
}

function refreshDatabases() {
    if (!postgresqlStatus.running) {
        return;
    }
    
    console.log('Refreshing database list...');
    
    const tableBody = document.getElementById('databaseTableBody');
    const sqlSelect = document.getElementById('sqlDatabase');
    
    // Mock database data
    const mockDatabases = [
        { name: 'postgres', owner: 'postgres', size: '8.2 MB', encoding: 'UTF8' },
        { name: 'template0', owner: 'postgres', size: '8.0 MB', encoding: 'UTF8' },
        { name: 'template1', owner: 'postgres', size: '8.0 MB', encoding: 'UTF8' },
        { name: 'myapp_db', owner: 'appuser', size: '15.3 MB', encoding: 'UTF8' },
        { name: 'test_db', owner: 'postgres', size: '8.1 MB', encoding: 'UTF8' }
    ];
    
    // Update table
    tableBody.innerHTML = '';
    sqlSelect.innerHTML = '<option value="">Select Database</option>';
    
    mockDatabases.forEach(db => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${db.name}</td>
            <td>${db.owner}</td>
            <td>${db.size}</td>
            <td>${db.encoding}</td>
            <td>
                <div class="table-actions">
                    <button class="btn btn-info" onclick="connectToDatabase('${db.name}')">
                        <i class="fas fa-plug"></i> Connect
                    </button>
                    ${db.name !== 'postgres' && db.name !== 'template0' && db.name !== 'template1' ? 
                        `<button class="btn btn-danger" onclick="dropDatabase('${db.name}')">
                            <i class="fas fa-trash"></i> Drop
                        </button>` : ''
                    }
                </div>
            </td>
        `;
        tableBody.appendChild(row);
        
        // Add to SQL select
        const option = document.createElement('option');
        option.value = db.name;
        option.textContent = db.name;
        sqlSelect.appendChild(option);
    });
}

function dropDatabase(dbName) {
    if (!confirm(`Are you sure you want to drop database '${dbName}'? This action cannot be undone.`)) {
        return;
    }
    
    console.log(`Dropping database: ${dbName}`);
    
    setTimeout(() => {
        showNotification(`Database '${dbName}' dropped successfully`, 'success');
        refreshDatabases();
    }, 1000);
}

function connectToDatabase(dbName) {
    console.log(`Connecting to database: ${dbName}`);
    
    // Set the database in SQL console
    document.getElementById('sqlDatabase').value = dbName;
    
    showNotification(`Connected to database '${dbName}'`, 'success');
    
    // Scroll to SQL console
    document.querySelector('.sql-console').scrollIntoView({ behavior: 'smooth' });
}

// User Management Functions
function createUser(event) {
    event.preventDefault();
    
    const username = document.getElementById('newUsername').value.trim();
    const password = document.getElementById('newUserPassword').value;
    const isSuperuser = document.getElementById('userSuperuser').checked;
    
    if (!username || !password) {
        showNotification('Username and password are required', 'warning');
        return;
    }
    
    console.log(`Creating user: ${username} (superuser: ${isSuperuser})`);
    
    setTimeout(() => {
        showNotification(`User '${username}' created successfully`, 'success');
        
        // Clear form
        document.getElementById('newUsername').value = '';
        document.getElementById('newUserPassword').value = '';
        document.getElementById('userSuperuser').checked = false;
        
        // Refresh user list
        refreshUsers();
    }, 1000);
}

function refreshUsers() {
    if (!postgresqlStatus.running) {
        return;
    }
    
    console.log('Refreshing user list...');
    
    const tableBody = document.getElementById('userTableBody');
    
    // Mock user data
    const mockUsers = [
        { username: 'postgres', superuser: true, createdb: true, createrole: true },
        { username: 'appuser', superuser: false, createdb: true, createrole: false },
        { username: 'readonly', superuser: false, createdb: false, createrole: false }
    ];
    
    tableBody.innerHTML = '';
    
    mockUsers.forEach(user => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${user.username}</td>
            <td><span class="status-indicator ${user.superuser ? 'running' : 'stopped'}"></span>${user.superuser ? 'Yes' : 'No'}</td>
            <td><span class="status-indicator ${user.createdb ? 'running' : 'stopped'}"></span>${user.createdb ? 'Yes' : 'No'}</td>
            <td><span class="status-indicator ${user.createrole ? 'running' : 'stopped'}"></span>${user.createrole ? 'Yes' : 'No'}</td>
            <td>
                <div class="table-actions">
                    <button class="btn btn-warning" onclick="changeUserPassword('${user.username}')">
                        <i class="fas fa-key"></i> Password
                    </button>
                    ${user.username !== 'postgres' ? 
                        `<button class="btn btn-danger" onclick="dropUser('${user.username}')">
                            <i class="fas fa-user-minus"></i> Drop
                        </button>` : ''
                    }
                </div>
            </td>
        `;
        tableBody.appendChild(row);
    });
}

function changeUserPassword(username) {
    const newPassword = prompt(`Enter new password for user '${username}':`);
    if (!newPassword) {
        return;
    }
    
    console.log(`Changing password for user: ${username}`);
    
    setTimeout(() => {
        showNotification(`Password changed for user '${username}'`, 'success');
    }, 1000);
}

function dropUser(username) {
    if (!confirm(`Are you sure you want to drop user '${username}'?`)) {
        return;
    }
    
    console.log(`Dropping user: ${username}`);
    
    setTimeout(() => {
        showNotification(`User '${username}' dropped successfully`, 'success');
        refreshUsers();
    }, 1000);
}

// SQL Console Functions
function executeSQLQuery() {
    const database = document.getElementById('sqlDatabase').value;
    const query = document.getElementById('sqlQuery').value.trim();
    const resultsEl = document.getElementById('sqlResults');
    
    if (!database) {
        showNotification('Please select a database first', 'warning');
        return;
    }
    
    if (!query) {
        showNotification('Please enter a SQL query', 'warning');
        return;
    }
    
    console.log(`Executing SQL query on ${database}: ${query}`);
    
    resultsEl.textContent = 'Executing query...';
    
    // Simulate query execution
    setTimeout(() => {
        // Mock results based on query type
        let mockResult;
        const lowerQuery = query.toLowerCase().trim();
        
        if (lowerQuery.includes('select') && lowerQuery.includes('information_schema.tables')) {
            mockResult = `table_catalog | table_schema | table_name  | table_type
${database}     | public       | users       | BASE TABLE
${database}     | public       | products    | BASE TABLE
${database}     | public       | orders      | BASE TABLE

(3 rows)`;
        } else if (lowerQuery.startsWith('select')) {
            mockResult = `id | name        | email
1  | John Doe    | john@example.com
2  | Jane Smith  | jane@example.com
3  | Bob Johnson | bob@example.com

(3 rows)`;
        } else if (lowerQuery.startsWith('create')) {
            mockResult = 'CREATE TABLE\nQuery executed successfully.';
        } else if (lowerQuery.startsWith('insert')) {
            mockResult = 'INSERT 0 1\nQuery executed successfully.';
        } else if (lowerQuery.startsWith('update')) {
            mockResult = 'UPDATE 2\nQuery executed successfully.';
        } else if (lowerQuery.startsWith('delete')) {
            mockResult = 'DELETE 1\nQuery executed successfully.';
        } else {
            mockResult = 'Query executed successfully.';
        }
        
        resultsEl.textContent = mockResult;
        showNotification('Query executed successfully', 'success');
    }, 1500);
}

function clearSQLConsole() {
    document.getElementById('sqlQuery').value = '';
    document.getElementById('sqlResults').textContent = 'Execute a query to see results...';
}

function updateDashboard() {
    // Update container overview
    const containerGrid = document.getElementById('containerGrid');
    containerGrid.innerHTML = '';
    
    containers.forEach(container => {
        const containerCard = document.createElement('div');
        containerCard.className = `container-card ${container.status}`;
        containerCard.onclick = () => showContainerDetails(container.id);
        
        containerCard.innerHTML = `
            <div class="container-name">${container.name}</div>
            <div class="container-status status-${container.status}">${container.status}</div>
            <div style="font-size: 0.8rem; color: #666; margin-top: 5px;">
                Port: ${container.ports[0]}
            </div>
        `;
        
        containerGrid.appendChild(containerCard);
    });
}

function loadContainers() {
    // Simulate API call to load containers
    console.log('Loading containers from Docker daemon...');
    
    // In a real implementation, this would make an API call to the server
    // which would execute: docker ps -a --format json
    
    setTimeout(() => {
        updateDashboard();
        console.log('Containers loaded successfully');
    }, 500);
}

function loadContainerList() {
    const containerList = document.getElementById('containerList');
    containerList.innerHTML = '';
    
    containers.forEach(container => {
        const containerItem = document.createElement('div');
        containerItem.className = 'container-item';
        
        containerItem.innerHTML = `
            <div class="container-info">
                <h4>${container.name}</h4>
                <p>Image: ${container.image}</p>
                <p>Created: ${new Date(container.created).toLocaleDateString()}</p>
            </div>
            <div class="container-status status-${container.status}">${container.status}</div>
            <div class="container-ports">${container.ports.join(', ')}</div>
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
                <button class="btn btn-primary" onclick="execIntoContainer('${container.id}')">
                    <i class="fas fa-terminal"></i> Exec
                </button>
            </div>
        `;
        
        containerList.appendChild(containerItem);
    });
}

function loadNginxList() {
    const nginxList = document.getElementById('nginxList');
    nginxList.innerHTML = '';
    
    const runningContainers = containers.filter(c => c.status === 'running');
    
    runningContainers.forEach(container => {
        const nginxItem = document.createElement('div');
        nginxItem.className = 'container-item';
        
        nginxItem.innerHTML = `
            <div class="container-info">
                <h4>${container.name}</h4>
                <p>Nginx Status: <span class="text-success">Active</span></p>
                <p>Config: /etc/nginx/nginx.conf</p>
            </div>
            <div class="text-success">Running</div>
            <div>${container.ports.join(', ')}</div>
            <div class="container-actions">
                <button class="btn btn-primary" onclick="reloadNginx('${container.id}')">
                    <i class="fas fa-sync-alt"></i> Reload
                </button>
                <button class="btn btn-info" onclick="testNginxConfig('${container.id}')">
                    <i class="fas fa-check"></i> Test
                </button>
                <button class="btn btn-secondary" onclick="editNginxConfig('${container.id}')">
                    <i class="fas fa-edit"></i> Edit
                </button>
            </div>
        `;
        
        nginxList.appendChild(nginxItem);
    });
    
    // Populate config selector
    const configSelect = document.getElementById('configSelect');
    configSelect.innerHTML = '<option value="">Select a container to edit config</option>';
    
    runningContainers.forEach(container => {
        const option = document.createElement('option');
        option.value = container.id;
        option.textContent = container.name;
        configSelect.appendChild(option);
    });
}

function loadMonitoringData() {
    const monitoringGrid = document.getElementById('monitoringGrid');
    monitoringGrid.innerHTML = '';
    
    const runningContainers = containers.filter(c => c.status === 'running');
    
    runningContainers.forEach(container => {
        const monitoringCard = document.createElement('div');
        monitoringCard.className = 'monitoring-card';
        
        monitoringCard.innerHTML = `
            <h4>${container.name}</h4>
            <div class="metric">
                <span>CPU Usage:</span>
                <span>${container.cpu.toFixed(1)}%</span>
            </div>
            <div class="metric">
                <span>Memory:</span>
                <span>${container.memory.toFixed(1)} MB</span>
            </div>
            <div class="metric">
                <span>Network I/O:</span>
                <span>${container.network.toFixed(1)} MB/s</span>
            </div>
            <div class="metric">
                <span>Status:</span>
                <span class="text-success">Healthy</span>
            </div>
        `;
        
        monitoringGrid.appendChild(monitoringCard);
    });
}

function populateContainerSelects() {
    const logSelect = document.getElementById('logContainerSelect');
    const terminalSelect = document.getElementById('terminalContainerSelect');
    
    // Clear existing options (except first one)
    logSelect.innerHTML = '<option value="">Select a container</option>';
    terminalSelect.innerHTML = '<option value="host">Host System</option>';
    
    containers.forEach(container => {
        const logOption = document.createElement('option');
        logOption.value = container.id;
        logOption.textContent = container.name;
        logSelect.appendChild(logOption);
        
        if (container.status === 'running') {
            const terminalOption = document.createElement('option');
            terminalOption.value = container.id;
            terminalOption.textContent = container.name;
            terminalSelect.appendChild(terminalOption);
        }
    });
}

// Container Management Functions
function startContainer(containerId) {
    console.log(`Starting container: ${containerId}`);
    // In real implementation: docker start ${containerId}
    
    const container = containers.find(c => c.id === containerId);
    if (container) {
        container.status = 'running';
        showNotification(`Container ${container.name} started successfully`, 'success');
        updateCurrentView();
    }
}

function stopContainer(containerId) {
    console.log(`Stopping container: ${containerId}`);
    // In real implementation: docker stop ${containerId}
    
    const container = containers.find(c => c.id === containerId);
    if (container) {
        container.status = 'stopped';
        showNotification(`Container ${container.name} stopped successfully`, 'warning');
        updateCurrentView();
    }
}

function restartContainer(containerId) {
    console.log(`Restarting container: ${containerId}`);
    // In real implementation: docker restart ${containerId}
    
    const container = containers.find(c => c.id === containerId);
    if (container) {
        showNotification(`Container ${container.name} restarted successfully`, 'info');
        updateCurrentView();
    }
}

function startAllContainers() {
    console.log('Starting all containers...');
    containers.forEach(container => {
        if (container.status === 'stopped') {
            container.status = 'running';
        }
    });
    showNotification('All containers started successfully', 'success');
    updateCurrentView();
}

function stopAllContainers() {
    console.log('Stopping all containers...');
    containers.forEach(container => {
        if (container.status === 'running') {
            container.status = 'stopped';
        }
    });
    showNotification('All containers stopped successfully', 'warning');
    updateCurrentView();
}

function restartAllContainers() {
    console.log('Restarting all containers...');
    showNotification('All containers restarted successfully', 'info');
    updateCurrentView();
}

function refreshContainers() {
    console.log('Refreshing container list...');
    loadContainers();
    showNotification('Container list refreshed', 'info');
}

// Nginx Management Functions
function reloadNginx(containerId) {
    console.log(`Reloading nginx in container: ${containerId}`);
    // In real implementation: docker exec ${containerId} nginx -s reload
    
    const container = containers.find(c => c.id === containerId);
    showNotification(`Nginx reloaded in ${container.name}`, 'success');
}

function reloadAllNginx() {
    console.log('Reloading nginx in all containers...');
    const runningContainers = containers.filter(c => c.status === 'running');
    runningContainers.forEach(container => {
        console.log(`Reloading nginx in: ${container.name}`);
    });
    showNotification('Nginx reloaded in all containers', 'success');
}

function testNginxConfig(containerId) {
    console.log(`Testing nginx config in container: ${containerId}`);
    // In real implementation: docker exec ${containerId} nginx -t
    
    const container = containers.find(c => c.id === containerId);
    showNotification(`Nginx config test passed for ${container.name}`, 'success');
}

function testAllNginxConfig() {
    console.log('Testing nginx config in all containers...');
    showNotification('All nginx configurations are valid', 'success');
}

function loadNginxConfig() {
    const select = document.getElementById('configSelect');
    const editor = document.getElementById('nginxConfigEditor');
    
    if (select.value) {
        const container = containers.find(c => c.id === select.value);
        editor.value = `# Nginx configuration for ${container.name}
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html index.htm;

        location / {
            try_files $uri $uri/ =404;
        }

        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
        }
    }
}`;
    } else {
        editor.value = 'Select a container to load its nginx configuration...';
    }
}

function saveNginxConfig() {
    const select = document.getElementById('configSelect');
    const editor = document.getElementById('nginxConfigEditor');
    
    if (!select.value) {
        showNotification('Please select a container first', 'warning');
        return;
    }
    
    const container = containers.find(c => c.id === select.value);
    console.log(`Saving nginx config for: ${container.name}`);
    // In real implementation: save config and reload nginx
    
    showNotification(`Nginx configuration saved for ${container.name}`, 'success');
}

// Monitoring Functions
function refreshStats() {
    console.log('Refreshing monitoring stats...');
    
    // Update container stats with random values
    containers.forEach(container => {
        if (container.status === 'running') {
            container.cpu = Math.random() * 50;
            container.memory = Math.random() * 512;
            container.network = Math.random() * 100;
        }
    });
    
    loadMonitoringData();
    showNotification('Monitoring stats refreshed', 'info');
}

function toggleAutoRefresh() {
    const checkbox = document.getElementById('autoRefresh');
    
    if (checkbox.checked) {
        autoRefreshInterval = setInterval(() => {
            if (currentSection === 'monitoring') {
                refreshStats();
            }
        }, 5000);
        showNotification('Auto-refresh enabled (5s interval)', 'info');
    } else {
        if (autoRefreshInterval) {
            clearInterval(autoRefreshInterval);
            autoRefreshInterval = null;
        }
        showNotification('Auto-refresh disabled', 'info');
    }
}

// Log Management Functions
function loadLogContainerSelect() {
    populateContainerSelects();
}

function loadContainerLogs() {
    const select = document.getElementById('logContainerSelect');
    const logContent = document.getElementById('logContent');
    
    if (!select.value) {
        logContent.textContent = 'Select a container to view its logs...';
        return;
    }
    
    const container = containers.find(c => c.id === select.value);
    console.log(`Loading logs for: ${container.name}`);
    
    // Mock log data
    const mockLogs = `2023-12-25 10:00:01 [info] nginx: starting server
2023-12-25 10:00:01 [info] nginx: server started successfully
2023-12-25 10:00:15 [info] 192.168.1.100 - - [25/Dec/2023:10:00:15 +0000] "GET / HTTP/1.1" 200 1234
2023-12-25 10:01:30 [info] 192.168.1.101 - - [25/Dec/2023:10:01:30 +0000] "GET /api/status HTTP/1.1" 200 567
2023-12-25 10:02:45 [info] 192.168.1.102 - - [25/Dec/2023:10:02:45 +0000] "POST /api/data HTTP/1.1" 201 89
2023-12-25 10:03:12 [warn] worker process 1234 exited on signal 15
2023-12-25 10:03:13 [info] start worker process 1235
2023-12-25 10:04:20 [info] 192.168.1.103 - - [25/Dec/2023:10:04:20 +0000] "GET /health HTTP/1.1" 200 12`;
    
    logContent.textContent = mockLogs;
}

function refreshLogs() {
    loadContainerLogs();
    showNotification('Logs refreshed', 'info');
}

function clearLogViewer() {
    document.getElementById('logContent').textContent = 'Select a container to view its logs...';
}

function toggleFollowLogs() {
    const checkbox = document.getElementById('followLogs');
    
    if (checkbox.checked) {
        logFollowInterval = setInterval(() => {
            const select = document.getElementById('logContainerSelect');
            if (select.value) {
                loadContainerLogs();
            }
        }, 2000);
        showNotification('Following logs (2s interval)', 'info');
    } else {
        if (logFollowInterval) {
            clearInterval(logFollowInterval);
            logFollowInterval = null;
        }
        showNotification('Stopped following logs', 'info');
    }
}

// Terminal Functions
function loadTerminalContainerSelect() {
    populateContainerSelects();
}

function connectToContainer() {
    const select = document.getElementById('terminalContainerSelect');
    const terminalTitle = document.getElementById('terminalTitle');
    
    if (select.value === 'host') {
        terminalTitle.textContent = 'Terminal - Host System';
        addTerminalLine('neofloppy@4.221.197.153:~$ ');
    } else {
        const container = containers.find(c => c.id === select.value);
        terminalTitle.textContent = `Terminal - ${container.name}`;
        addTerminalLine(`root@${container.id.substring(0, 12)}:/# `);
    }
}

function clearTerminal() {
    const terminalContent = document.getElementById('terminalContent');
    terminalContent.innerHTML = '<div class="terminal-line">neofloppy@4.221.197.153:~$ <span class="cursor">_</span></div>';
}

function handleTerminalInput(event) {
    if (event.key === 'Enter') {
        const input = document.getElementById('terminalInput');
        const command = input.value.trim();
        
        if (command) {
            executeTerminalCommand(command);
            input.value = '';
        }
    }
}

function executeTerminalCommand(command) {
    const select = document.getElementById('terminalContainerSelect');
    const isHost = select.value === 'host';
    
    // Remove cursor from last line
    const terminalContent = document.getElementById('terminalContent');
    const lastLine = terminalContent.lastElementChild;
    if (lastLine) {
        lastLine.innerHTML = lastLine.innerHTML.replace('<span class="cursor">_</span>', '');
    }
    
    // Add command to terminal
    addTerminalLine(command);
    
    // Execute command and show output
    setTimeout(() => {
        const output = executeCommand(command, isHost);
        if (output) {
            addTerminalLine(output);
        }
        
        // Add new prompt
        if (isHost) {
            addTerminalLine('neofloppy@4.221.197.153:~$ <span class="cursor">_</span>');
        } else {
            const container = containers.find(c => c.id === select.value);
            addTerminalLine(`root@${container.id.substring(0, 12)}:/# <span class="cursor">_</span>`);
        }
    }, 100);
}

function executeCommand(command, isHost) {
    // Mock command execution
    const cmd = command.toLowerCase();
    
    if (cmd === 'docker ps') {
        return containers.map(c => 
            `${c.id.substring(0, 12)}  ${c.image}  "${c.status}"  ${c.ports[0]}  ${c.name}`
        ).join('\n');
    } else if (cmd === 'docker ps -a') {
        return 'CONTAINER ID  IMAGE         STATUS    PORTS     NAMES\n' + 
               containers.map(c => 
                   `${c.id.substring(0, 12)}  ${c.image.padEnd(12)}  ${c.status.padEnd(8)}  ${c.ports[0].padEnd(8)}  ${c.name}`
               ).join('\n');
    } else if (cmd === 'ls') {
        return isHost ? 'docker-compose.yml  nginx-configs  logs  scripts' : 'bin  etc  usr  var  tmp';
    } else if (cmd === 'pwd') {
        return isHost ? '/home/neofloppy' : '/';
    } else if (cmd === 'whoami') {
        return isHost ? 'neofloppy' : 'root';
    } else if (cmd === 'date') {
        return new Date().toString();
    } else if (cmd === 'help') {
        return 'Available commands: docker ps, docker ps -a, ls, pwd, whoami, date, help, clear';
    } else if (cmd === 'clear') {
        clearTerminal();
        return '';
    } else {
        return `bash: ${command}: command not found`;
    }
}

function addTerminalLine(content) {
    const terminalContent = document.getElementById('terminalContent');
    const line = document.createElement('div');
    line.className = 'terminal-line';
    line.innerHTML = content;
    terminalContent.appendChild(line);
    terminalContent.scrollTop = terminalContent.scrollHeight;
}

// Modal Functions
function showContainerDetails(containerId) {
    const container = containers.find(c => c.id === containerId);
    const modal = document.getElementById('containerModal');
    const modalTitle = document.getElementById('modalTitle');
    const modalBody = document.getElementById('modalBody');
    
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
                <h4>Resource Usage</h4>
                <p><strong>CPU:</strong> ${container.cpu.toFixed(1)}%</p>
                <p><strong>Memory:</strong> ${container.memory.toFixed(1)} MB</p>
                <p><strong>Network:</strong> ${container.network.toFixed(1)} MB/s</p>
                <p><strong>Ports:</strong> ${container.ports.join(', ')}</p>
            </div>
        </div>
        <div style="margin-top: 20px;">
            <h4>Actions</h4>
            <div style="display: flex; gap: 10px; margin-top: 10px;">
                ${container.status === 'running' ? 
                    `<button class="btn btn-warning" onclick="stopContainer('${container.id}'); closeModal();">Stop</button>
                     <button class="btn btn-secondary" onclick="restartContainer('${container.id}'); closeModal();">Restart</button>` :
                    `<button class="btn btn-success" onclick="startContainer('${container.id}'); closeModal();">Start</button>`
                }
                <button class="btn btn-primary" onclick="execIntoContainer('${container.id}'); closeModal();">Execute Shell</button>
            </div>
        </div>
    `;
    
    modal.style.display = 'block';
}

function closeModal() {
    document.getElementById('containerModal').style.display = 'none';
}

function execIntoContainer(containerId) {
    const container = containers.find(c => c.id === containerId);
    
    if (container.status !== 'running') {
        showNotification('Container must be running to execute shell', 'warning');
        return;
    }
    
    // Switch to terminal section and connect to container
    showSection('terminal');
    
    setTimeout(() => {
        const select = document.getElementById('terminalContainerSelect');
        select.value = containerId;
        connectToContainer();
        showNotification(`Connected to ${container.name}`, 'success');
    }, 100);
}

// Utility Functions
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

function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <i class="fas fa-${getNotificationIcon(type)}"></i>
        <span>${message}</span>
        <button onclick="this.parentElement.remove()">&times;</button>
    `;
    
    // Add styles
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
    
    // Add to page
    document.body.appendChild(notification);
    
    // Auto remove after 5 seconds
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

function logout() {
    if (confirm('Are you sure you want to logout?')) {
        showNotification('Logging out...', 'info');
        setTimeout(() => {
            window.location.reload();
        }, 1000);
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
`;
document.head.appendChild(style);
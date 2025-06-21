# ServerPulse Agent - Laravel Integration Guide

## Quick Installation on Ubuntu VM

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd serverpulse-agent
   ```

2. **Run the one-click installer:**
   ```bash
   sudo ./easy_install.sh
   ```
   
   The script will:
   - Install all dependencies
   - Set up the agent in `/opt/serverpulse-agent`
   - Create a system service
   - Ask for your Laravel URL and auth token
   - Start monitoring automatically

That's it! No more complex setup.

---

## Laravel Backend Integration

### 1. Create API Routes

Add these routes to your `routes/api.php`:

```php
<?php
// Agent API routes
Route::prefix('v1/agents')->group(function () {
    Route::post('register', [AgentController::class, 'register']);
    Route::post('{agent_id}/metrics', [AgentController::class, 'receiveMetrics']);
    Route::post('{agent_id}/heartbeat', [AgentController::class, 'heartbeat']);
    Route::post('{agent_id}/alerts', [AgentController::class, 'receiveAlert']);
    Route::get('{agent_id}/commands', [AgentController::class, 'getCommands']);
});
```

### 2. Create Database Migrations

**Agents table:**
```php
<?php
// database/migrations/create_agents_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAgentsTable extends Migration
{
    public function up()
    {
        Schema::create('agents', function (Blueprint $table) {
            $table->id();
            $table->string('agent_id')->unique();
            $table->string('hostname');
            $table->string('ip_address')->nullable();
            $table->string('system');
            $table->string('release')->nullable();
            $table->string('version')->nullable();
            $table->enum('status', ['online', 'offline', 'error'])->default('offline');
            $table->timestamp('last_heartbeat')->nullable();
            $table->json('agent_info')->nullable();
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('agents');
    }
}
```

**Metrics table:**
```php
<?php
// database/migrations/create_agent_metrics_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAgentMetricsTable extends Migration
{
    public function up()
    {
        Schema::create('agent_metrics', function (Blueprint $table) {
            $table->id();
            $table->string('agent_id');
            $table->json('metrics');
            $table->timestamp('collected_at');
            $table->timestamps();
            
            $table->index(['agent_id', 'collected_at']);
            $table->foreign('agent_id')->references('agent_id')->on('agents');
        });
    }

    public function down()
    {
        Schema::dropIfExists('agent_metrics');
    }
}
```

**Alerts table:**
```php
<?php
// database/migrations/create_agent_alerts_table.php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAgentAlertsTable extends Migration
{
    public function up()
    {
        Schema::create('agent_alerts', function (Blueprint $table) {
            $table->id();
            $table->string('agent_id');
            $table->string('type');
            $table->enum('severity', ['low', 'medium', 'high', 'critical']);
            $table->string('message');
            $table->json('details')->nullable();
            $table->boolean('acknowledged')->default(false);
            $table->timestamp('occurred_at');
            $table->timestamps();
            
            $table->index(['agent_id', 'severity', 'acknowledged']);
            $table->foreign('agent_id')->references('agent_id')->on('agents');
        });
    }

    public function down()
    {
        Schema::dropIfExists('agent_alerts');
    }
}
```

### 3. Create Agent Controller

```php
<?php
// app/Http/Controllers/AgentController.php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Agent;
use App\Models\AgentMetric;
use App\Models\AgentAlert;
use Carbon\Carbon;

class AgentController extends Controller
{
    public function register(Request $request)
    {
        $validated = $request->validate([
            'agent_id' => 'required|string',
            'hostname' => 'required|string',
            'system' => 'required|string',
            'release' => 'nullable|string',
            'version' => 'nullable|string',
        ]);

        $agent = Agent::updateOrCreate(
            ['agent_id' => $validated['agent_id']],
            [
                'hostname' => $validated['hostname'],
                'ip_address' => $request->ip(),
                'system' => $validated['system'],
                'release' => $validated['release'],
                'version' => $validated['version'],
                'status' => 'online',
                'last_heartbeat' => now(),
                'agent_info' => $request->all(),
            ]
        );

        return response()->json([
            'success' => true,
            'message' => 'Agent registered successfully',
            'agent_id' => $agent->agent_id
        ]);
    }

    public function receiveMetrics(Request $request, $agent_id)
    {
        $validated = $request->validate([
            'metrics' => 'required|array',
            'timestamp' => 'required|date',
        ]);

        // Update agent last seen
        Agent::where('agent_id', $agent_id)->update([
            'status' => 'online',
            'last_heartbeat' => now(),
        ]);

        // Store metrics
        AgentMetric::create([
            'agent_id' => $agent_id,
            'metrics' => $validated['metrics'],
            'collected_at' => $validated['timestamp'],
        ]);

        // Check for alerts based on metrics
        $this->checkMetricsForAlerts($agent_id, $validated['metrics']);

        return response()->json(['success' => true]);
    }

    public function heartbeat(Request $request, $agent_id)
    {
        Agent::where('agent_id', $agent_id)->update([
            'status' => 'online',
            'last_heartbeat' => now(),
        ]);

        return response()->json(['success' => true]);
    }

    public function receiveAlert(Request $request, $agent_id)
    {
        $validated = $request->validate([
            'alert.type' => 'required|string',
            'alert.severity' => 'required|string',
            'alert.message' => 'required|string',
            'alert.details' => 'nullable|array',
            'timestamp' => 'required|date',
        ]);

        AgentAlert::create([
            'agent_id' => $agent_id,
            'type' => $validated['alert']['type'],
            'severity' => $validated['alert']['severity'],
            'message' => $validated['alert']['message'],
            'details' => $validated['alert']['details'] ?? null,
            'occurred_at' => $validated['timestamp'],
        ]);

        return response()->json(['success' => true]);
    }

    public function getCommands(Request $request, $agent_id)
    {
        // Return any pending commands for the agent
        return response()->json(['commands' => []]);
    }

    private function checkMetricsForAlerts($agent_id, $metrics)
    {
        // Check CPU usage
        if (isset($metrics['cpu']['usage_percent']) && $metrics['cpu']['usage_percent'] > 90) {
            AgentAlert::create([
                'agent_id' => $agent_id,
                'type' => 'high_cpu',
                'severity' => 'high',
                'message' => 'CPU usage is above 90%: ' . $metrics['cpu']['usage_percent'] . '%',
                'details' => ['cpu_usage' => $metrics['cpu']['usage_percent']],
                'occurred_at' => now(),
            ]);
        }

        // Check memory usage
        if (isset($metrics['memory']['virtual']['percent']) && $metrics['memory']['virtual']['percent'] > 90) {
            AgentAlert::create([
                'agent_id' => $agent_id,
                'type' => 'high_memory',
                'severity' => 'high',
                'message' => 'Memory usage is above 90%: ' . $metrics['memory']['virtual']['percent'] . '%',
                'details' => ['memory_usage' => $metrics['memory']['virtual']['percent']],
                'occurred_at' => now(),
            ]);
        }

        // Check disk usage
        if (isset($metrics['disk']['usage'])) {
            foreach ($metrics['disk']['usage'] as $mount => $disk) {
                if ($disk['percent'] > 90) {
                    AgentAlert::create([
                        'agent_id' => $agent_id,
                        'type' => 'high_disk',
                        'severity' => 'high',
                        'message' => "Disk usage on $mount is above 90%: " . $disk['percent'] . '%',
                        'details' => ['mount' => $mount, 'disk_usage' => $disk['percent']],
                        'occurred_at' => now(),
                    ]);
                }
            }
        }
    }
}
```

### 4. Create Models

```php
<?php
// app/Models/Agent.php
namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Agent extends Model
{
    protected $fillable = [
        'agent_id', 'hostname', 'ip_address', 'system', 'release', 
        'version', 'status', 'last_heartbeat', 'agent_info'
    ];

    protected $casts = [
        'agent_info' => 'array',
        'last_heartbeat' => 'datetime',
    ];

    public function metrics()
    {
        return $this->hasMany(AgentMetric::class, 'agent_id', 'agent_id');
    }

    public function alerts()
    {
        return $this->hasMany(AgentAlert::class, 'agent_id', 'agent_id');
    }

    public function latestMetrics()
    {
        return $this->hasOne(AgentMetric::class, 'agent_id', 'agent_id')
                    ->orderBy('collected_at', 'desc');
    }
}
```

### 5. Authentication Setup

Add authentication to your agent API routes:

```php
// In routes/api.php
Route::middleware('auth:agent')->prefix('v1/agents')->group(function () {
    // ... your agent routes
});
```

Create an agent authentication guard or use Laravel Sanctum tokens.

---

## Connection Setup

### 1. Get Your Laravel Server URL
If using Laragon on Windows and your Ubuntu VM is on the same network:
```
http://YOUR_WINDOWS_IP:80/api/v1
```

### 2. Create Authentication Token
In your Laravel app, create an API token for the agent to use.

### 3. Configure Agent
When you run `sudo ./easy_install.sh`, it will ask for:
- **ServerPulse URL**: `http://192.168.1.100:80` (your Windows IP)
- **Auth Token**: The token from your Laravel app

---

## Testing

After installation, test the connection:
```bash
sudo -u serverpulse /opt/serverpulse-agent/venv/bin/python /opt/serverpulse-agent/agent_cli.py test-connection
```

View metrics being collected:
```bash
sudo -u serverpulse /opt/serverpulse-agent/venv/bin/python /opt/serverpulse-agent/agent_cli.py collect-metrics
```

---

## Dashboard Integration

In your Laravel dashboard, you can now display:
- Real-time server metrics
- Service status
- Alert notifications
- Historical data charts

The agent will automatically send data every 30 seconds to your Laravel backend!

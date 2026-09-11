import readline from 'node:readline';
import {buildStorytellerContext} from '../../storyteller-runtime.mjs';
import {WAYFOLIO_MCP_TOOL_DEFINITIONS, WayfolioMCPToolBridge} from './wayfolio-mcp-tools.mjs';

const demoContext = buildStorytellerContext({
  sessionId:'WAYFOLIO-POC', turnId:process.env.WAYFOLIO_POC_TURN_ID || 'poc-turn-1', stateVersion:0,
  sceneId:'hemlock-bridge', trigger:'player_action', causationId:'poc-action-1',
  playerInput:{actorCharacterId:'renn', rawIntent:'I study the blue motes without disturbing them.'},
  canon:{continuitySummary:['Renn, Soren, and Lupin are together near Hemlock Bridge.']},
  scene:{locationId:'hemlock-bridge', companions:['soren', 'lupin']},
  mechanics:{system:'5e-compatible'}, knowledge:{renn:['Blue motes have gathered beneath the bridge.']},
  capabilities:{openEndedPlay:true, privateDeliveries:true, physicalOrDigitalDice:true},
});

const bridge = new WayfolioMCPToolBridge();
bridge.registerTurn(demoContext);

function result(id, value) {
  return {jsonrpc:'2.0', id, result:value};
}

function error(id, caught) {
  return {jsonrpc:'2.0', id, error:{code:-32000, message:caught?.message || String(caught)}};
}

async function handle(message) {
  const {id, method, params = {}} = message;
  if (method === 'initialize') return result(id, {
    protocolVersion:params.protocolVersion || '2025-06-18',
    capabilities:{tools:{}}, serverInfo:{name:'wayfolio-workspace-agent-poc', version:'0.1.0'},
  });
  if (method === 'notifications/initialized') return null;
  if (method === 'tools/list') return result(id, {tools:WAYFOLIO_MCP_TOOL_DEFINITIONS});
  if (method === 'tools/call') {
    const value = await bridge.callTool(params.name, params.arguments || {});
    return result(id, {content:[{type:'text', text:JSON.stringify(value)}], structuredContent:value, isError:false});
  }
  return {jsonrpc:'2.0', id, error:{code:-32601, message:`Method not found: ${method}`}};
}

const input = readline.createInterface({input:process.stdin, crlfDelay:Infinity});
input.on('line', async line => {
  if (!line.trim()) return;
  let response;
  try { response = await handle(JSON.parse(line)); }
  catch (caught) { response = error(null, caught); }
  if (response) process.stdout.write(`${JSON.stringify(response)}\n`);
});

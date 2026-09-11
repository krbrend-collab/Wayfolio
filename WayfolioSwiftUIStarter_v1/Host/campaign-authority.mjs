import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {readFile} from 'node:fs/promises';

const execute = promisify(execFile);
const starterRoot = fileURLToPath(new URL('..', import.meta.url));
export const campaignRoot = process.env.WAYFOLIO_CAMPAIGN_PATH
  ? resolve(process.env.WAYFOLIO_CAMPAIGN_PATH)
  : join(starterRoot, 'Campaigns', 'HemlockDevelopment');
const enginePath = join(starterRoot, 'Tools', 'aidm_campaign.py');
const manifestPath = join(campaignRoot, 'CAMPAIGN_MANIFEST.json');

async function runEngine(argumentsList) {
  try {
    const {stdout} = await execute('python3', [enginePath, ...argumentsList], {
      env:{...process.env, PYTHONDONTWRITEBYTECODE:'1'},
      maxBuffer:2 * 1024 * 1024,
    });
    return JSON.parse(stdout);
  } catch (error) {
    let detail = error.stderr || error.stdout || error.message;
    try { detail = JSON.parse(detail).error || detail; } catch {}
    throw new Error(`Campaign authority rejected the operation: ${String(detail).trim()}`);
  }
}

export async function initializeCampaignAuthority() {
  // Contract 1.1 requires the manifest to be selected and read before validation.
  const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
  const validation = await runEngine(['validate', '--campaign', campaignRoot]);
  if (validation.status !== 'PASS') {
    throw new Error(`Hemlock campaign validation failed: ${validation.errors.join('; ')}`);
  }
  const status = await runEngine(['command', '--campaign', campaignRoot, '--name', '/status']);
  return {
    campaignID:manifest.campaign_id,
    stateHead:validation.state_head,
    transactionHash:validation.transaction_hash,
    contract:validation.contract,
    production:validation.production,
    status:status.content,
  };
}

export async function commitCampaignTurn({consequence, nextWorld, characterState}) {
  const resources = {
    party:nextWorld.party,
    active_entities:nextWorld.active_entities,
    known_clues:nextWorld.known_clues,
    inventory_count:characterState.inventory.length,
    discoveries_count:characterState.discoveries.length,
  };
  const campaignTime = {
    axis:'hemlock-local',
    period:nextWorld.time.period,
    elapsed_minutes:nextWorld.time.elapsed_minutes,
  };
  const delta = {
    status_patch:{campaign_time:campaignTime, location:nextWorld.location?.name || null, resources},
    timeline_append:[{
      event_id:`event:${consequence.turn_id}`,
      campaign_time:campaignTime,
      summary:consequence.public_narration,
      provenance:consequence.provenance,
    }],
    recap_append:[{
      recap_id:`recap:${consequence.turn_id}`,
      campaign_time:campaignTime,
      text:consequence.public_narration,
      provenance:consequence.provenance,
    }],
    source_references:[
      'Wayfolio DM-reviewed open-play consequence',
      `adjudication:${consequence.adjudication_source}`,
    ],
  };
  return runEngine([
    'turn',
    '--campaign', campaignRoot,
    '--turn-id', consequence.turn_id,
    '--declaration', consequence.declaration,
    '--delta-json', JSON.stringify(delta),
    '--expected-head', consequence.prior_state_head,
    '--phase-after', 'Open Play',
    '--campaign-time-after-json', JSON.stringify(campaignTime),
  ]);
}

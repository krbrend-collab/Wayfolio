import {buildResolutionPacket, prepareStorytellerTurn, validateStorytellerTurn} from './storyteller-runtime.mjs';

export class StorytellerAdapter {
  constructor({generate}) {
    if (typeof generate !== 'function') throw new Error('StorytellerAdapter requires a generate function.');
    this.generate = generate;
  }

  async begin({state, context}) {
    const rawTurn = await this.generate({messageType:'StorytellerContext', context});
    const validation = validateStorytellerTurn(rawTurn);
    if (!validation.valid) return {status:'REPAIR_REQUIRED', errors:validation.errors, state};
    return prepareStorytellerTurn(state, context, validation.value);
  }

  async complete({state, context, resolutionResults}) {
    const resolutionPacket = buildResolutionPacket(state, {turnId:context.turnId,
      stateVersion:state.stateVersion, results:resolutionResults});
    if (resolutionPacket.status === 'STALE_STATE') return resolutionPacket;
    const rawTurn = await this.generate({messageType:'ResolutionPacket', context, resolutionPacket});
    const validation = validateStorytellerTurn(rawTurn);
    if (!validation.valid) return {status:'REPAIR_REQUIRED', errors:validation.errors, state, resolutionPacket};
    const prepared = prepareStorytellerTurn(state, context, validation.value);
    if (prepared.status === 'NEEDS_RESOLUTION') {
      return {status:'REPAIR_REQUIRED', errors:['A resolved turn requested another unresolved result.'], state, resolutionPacket};
    }
    return {...prepared, resolutionPacket};
  }

  async repair({state, context, rejectedTurn, reasons}) {
    const rawTurn = await this.generate({messageType:'RepairContext', context,
      repair:{rejectedTurn, reasons:Array.isArray(reasons) ? reasons.map(String) : [String(reasons)]}});
    const validation = validateStorytellerTurn(rawTurn);
    if (!validation.valid) return {status:'REPAIR_REQUIRED', errors:validation.errors, state};
    return prepareStorytellerTurn(state, context, validation.value);
  }
}

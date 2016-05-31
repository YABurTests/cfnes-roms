import logger from '../../../core/src/utils/logger';

const ports = [1, 2];
const sourceTypes = ['keyboard', 'mouse', 'gamepad'];
const deviceTypes = ['joypad', 'zapper'];

//=========================================================
// Input module
//=========================================================

export default class InputModule {

  constructor() {
    this.dependencies = ['nes', 'deviceFactory'];
  }

  inject(nes, deviceFactory) {
    logger.info('Initializing input module');
    this.nes = nes;
    this.deviceFactory = deviceFactory;
    this.initSources();
    this.initDevices();
    this.initOptions();
  }

  initOptions() {
    const defaultDevices = ['joypad', 'zapper'];
    const defaultMapping = {
      '1.joypad.a': 'keyboard.x',
      '1.joypad.b': ['keyboard.y', 'keyboard.z'],
      '1.joypad.start': 'keyboard.enter',
      '1.joypad.select': 'keyboard.shift',
      '1.joypad.up': 'keyboard.up',
      '1.joypad.down': 'keyboard.down',
      '1.joypad.left': 'keyboard.left',
      '1.joypad.right': 'keyboard.right',
      '2.zapper.trigger': 'mouse.left',
    };
    this.options = [
      {name: 'inputDevices', get: this.getDevices, set: this.setDevices, def: defaultDevices},
      {name: 'inputMapping', get: this.getMapping, set: this.setMapping, def: defaultMapping},
    ];
  }

  //=========================================================
  // Sources
  //=========================================================

  initSources() {
    this.sources = {};
    for (const type of sourceTypes) {
      logger.info(`Registering "${type}" source`);
      this.sources[type] = this.deviceFactory.createSource(type);
    }
  }

  //=========================================================
  // Devices
  //=========================================================

  initDevices() {
    this.adapters = {};
    for (const port of ports) {
      this.adapters[port] = {};
      for (const type of deviceTypes) {
        logger.info(`Registering "${type}" device on port ${port}`);
        this.adapters[port][type] = this.deviceFactory.createAdapter(type);
      }
    }
  }

  setDevice(port, type) {
    if (this.getDevice(port) !== type) {
      logger.info(`Setting device on port ${port} to "${type || 'none'}"`);
      const adapter = this.adapters[port][type];
      const device = adapter != null ? adapter.getDevice() : null;
      this.nes.setInputDevice(port, device);
    }
  }

  getDevice(port) {
    const adaptersOnPort = this.adapters[port];
    for (const type in adaptersOnPort) {
      const adapter = adaptersOnPort[type];
      if (this.nes.getInputDevice(port) === adapter.getDevice()) {
        return type;
      }
    }
    return null;
  }

  setDevices(types) {
    for (const port of ports) {
      this.setDevice(port, types[port - 1]);
    }
  }

  getDevices() {
    return ports.map(this.getDevice, this);
  }

  //=========================================================
  // State
  //=========================================================

  updateState() {
    const state = {};
    for (const type in this.sources) {
      const source = this.sources[type];
      if (source.readState) {
        source.readState(state);
      }
    }
    for (const port in this.adapters) {
      const adaptersOnPort = this.adapters[port];
      for (const type in adaptersOnPort) {
        const adapter = adaptersOnPort[type];
        if (adapter.stateChanged) {
          adapter.stateChanged(state);
        }
      }
    }
  }

  //=========================================================
  // Input processing
  //=========================================================

  processInput(sourceInput, down) {
    if (this.isRecording()) {
      if (!down) {
        this.finishRecording(sourceInput);
      }
      return true;
    }
    return this.forwardInput(sourceInput, down);
  }

  forwardInput(sourceInput, down) {
    let inputProcessed = false;
    for (const mappingItem of this.mapping) {
      if (hasSourceInput(mappingItem, sourceInput)) {
        const {device, port, name} = mappingItem.deviceInput;
        this.adapters[port][device].inputChanged(name, down);
        inputProcessed = true;
      }
    }
    return inputProcessed;
  }

  //=========================================================
  // Input recording
  //=========================================================

  recordInput(callback) {
    logger.info('Recording input');
    this.recordCallback = callback;
  }

  isRecording() {
    return this.recordCallback != null;
  }

  finishRecording(sourceInput) {
    logger.info(`Caught input "${sourceInput.name}" from "${sourceInput.source}"`);
    this.recordCallback(makeSourceDescriptor(sourceInput));
    this.recordCallback = null;
  }

  //=========================================================
  // Input mapping
  //=========================================================

  setMapping(mapping) {
    this.unmapInputs();
    for (const deviceDesciptor in mapping) {
      const sourceDescriptors = mapping[deviceDesciptor];
      this.mapInputs(deviceDesciptor, sourceDescriptors);
    }
  }

  getMapping() {
    const mapping = {};
    for (const mappingItem of this.mapping) {
      const sourceDescriptor = makeSourceDescriptor(mappingItem.sourceInput);
      const deviceDescriptor = makeDeviceDescriptor(mappingItem.deviceInput);
      if (mapping[deviceDescriptor] == null) {
        mapping[deviceDescriptor] = [];
      }
      mapping[deviceDescriptor].push(sourceDescriptor);
    }
    return mapping;
  }

  mapInputs(deviceDescriptor, sourceDescriptors) {
    if (typeof sourceDescriptors === 'string') {
      sourceDescriptors = [sourceDescriptors];
    }
    const deviceInput = parseDeviceDescriptor(deviceDescriptor);
    for (const sourceDescriptor of sourceDescriptors) {
      const sourceInput = parseSourceDescriptor(sourceDescriptor);
      for (const mappingItem of this.mapping) {
        if (hasSourceInput(mappingItem, sourceInput) && hasDeviceInput(mappingItem, deviceInput)) {
          return;
        }
      }
      logger.info(`Mapping "${deviceInput.name}" of "${deviceInput.device}" on port "${deviceInput.port}" to "${sourceInput.name}" of "${sourceInput.source}"`);
      this.mapping.push({sourceInput, deviceInput});
    }
  }

  unmapInputs(...descriptors) {
    if (!descriptors.length) {
      logger.info('Unmapping all inputs');
      this.mapping = [];
      return;
    }
    for (const descriptor of descriptors) {
      const deviceInput = parseDeviceDescriptor(descriptor);
      if (deviceInput.port) {
        logger.info(`Unmapping "${deviceInput.name}" of "${deviceInput.device}" on port "${deviceInput.port}"`);
        this.mapping = this.mapping.filter(mappingItem => !hasDeviceInput(mappingItem, deviceInput));
      } else {
        const sourceInput = parseSourceDescriptor(descriptor);
        logger.info(`Unmapping "${sourceInput.name}" of "${sourceInput.source}"`);
        this.mapping = this.mapping.filter(mappingItem => !hasSourceInput(mappingItem, sourceInput));
      }
    }
  }

  getMappedInputs(descriptor) {
    const result = [];
    const deviceInput = parseDeviceDescriptor(descriptor);
    if (deviceInput.port) {
      for (const mappingItem of this.mapping) {
        if (hasDeviceInput(mappingItem, deviceInput)) {
          result.push(makeSourceDescriptor(mappingItem.sourceInput));
        }
      }
    } else {
      const sourceInput = parseSourceDescriptor(descriptor);
      for (const mappingItem of this.mapping) {
        if (hasSourceInput(mappingItem, sourceInput)) {
          result.push(makeDeviceDescriptor(mappingItem.deviceInput));
        }
      }
    }
    return result;
  }

}

//=========================================================
// Input descriptors
//=========================================================

function makeSourceDescriptor(input) {
  return `${input.source}.${input.name}`;
}

function makeDeviceDescriptor(input) {
  return `${input.port}.${input.device}.${input.name}`;
}

function parseSourceDescriptor(descriptor) {
  const [source, name] = descriptor.split('.');
  return {source, name};
}

function parseDeviceDescriptor(descriptor) {
  const [portString, device, name] = descriptor.split('.');
  const port = parseInt(portString);
  return {port, device, name};
}

function hasSourceInput(mappingItem, sourceInput) {
  const source1 = mappingItem.sourceInput.source;
  const source2 = sourceInput.source;
  const name1 = mappingItem.sourceInput.name;
  const name2 = sourceInput.name;
  return isSameSource(source1, source2) && name1 === name2;
}

function isSameSource(source1, source2) {
  return source1 === 'gamepad' && source2.startsWith(source1) || source1 === source2;
}

function hasDeviceInput(mappingItem, deviceInput) {
  const port1 = mappingItem.deviceInput.port;
  const port2 = deviceInput.port;
  const device1 = mappingItem.deviceInput.device;
  const device2 = deviceInput.device;
  const name1 = mappingItem.deviceInput.name;
  const name2 = deviceInput.name;
  return port1 === port2 && device1 === device2 && name1 === name2;
}
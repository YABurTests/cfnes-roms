# cfxnes API

Note: This documentation is for the upcoming version 0.5.0

- [cfxnes](#user-content-cfxnesoptions)
- [nes](#user-content-nes)
- [nes.rom](#user-content-nesrom)
- [nes.nvram](#user-content-nesnvram)
- [nes.video](#user-content-nesvideo)
- [nes.fullscreen](#user-content-nesfullscreen)
- [nes.audio](#user-content-nesaudio)
- [nes.devices](#user-content-nesdevices)
- [nes.inputs](#user-content-nesinputs)
- [nes.config](#user-content-nesconfig)

## cfxnes([options])

Function that returns new emulator instance.

**options** - initialization options. See the following documentation sections for their description.

``` javascript
let nes;

// No options specified.
nes = cfxnes();

// All options and their default values.
nes = cfxnes({
  region: 'auto',
  speed: 1,
  rom: undefined,
  JSZip: undefined,
  video: {
    output: null,
    renderer: 'webgl',
    scale: 1,
    palette: 'fceux',
    smoothing: false,
    debug: false,
  },
  fullscreen: {
    type: 'maximized',
  }
  audio: {
    enabled: true,
    volume: {
      master: 0.5,
      pulse1: 1,
      pulse2: 1,
      triangle: 1,
      noise: 1,
      dmc: 1,
    },
  },
  devices: {
    1: 'joypad',
    2: 'zapper',
  },
  inputs: {
    '1.joypad.a': 'keyboard.x',
    '1.joypad.b': ['keyboard.y', 'keyboard.z'],
    '1.joypad.start': 'keyboard.enter',
    '1.joypad.select': 'keyboard.shift',
    '1.joypad.up': 'keyboard.up',
    '1.joypad.down': 'keyboard.down',
    '1.joypad.left': 'keyboard.left',
    '1.joypad.right': 'keyboard.right',
    '2.zapper.trigger': 'mouse.left',
  },
});

```

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| version | `string` | no |  | cfxnes version. |
| logLevel | `string` | yes | `'warn'` | Verbosity of logging for all emulator instances.<br>`'off'` - Logging is disabled.<br>`'error'` - Log errors.<br>`'warn'` - Log errors and warnings.<br>`'info'` - Log errors, warnings and info messages. |

``` javascript
cfxnes.version; // '0.4.0', '1.0.0', '1.2.1', etc.

cfxnes.logLevel = 'off'; // Disable logging
cfxnes.logLevel = 'info'; // Log everything

```

## nes

Emulator instance returned by the `cfxnes` function.

It defines basic (execution-related) properties/methods and aggregates various submodules (`rom`, `video`, `fullscreen`, `audio`, `devices`, `inputs`).

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| running | `number` | no | `false` | `true` when emulator is running, `false` otherwise. |
| fps  | `number` | no || Number of frames per second of running emulator. |
| region | `string` | yes | `'auto'` | Emulated NES region.<br>`'auto'` - Automatic region detection (not very reliable).<br>`'ntsc'` - NTSC region (60 FPS).<br>`'pal'` - PAL region (50 FPS). |
| speed | `number` | yes | `1` | Emulation speed multiplier. It must be larger than 0. |
| nvram | `Uint8Array` | no | null | Provides access to NVRAM. NVRAM (Non-Volatile RAM) is a memory that is usually battery-backed and serves as a place for game saves. NVRAM is only used by some games (e.g., The Legend of Zelda or Final Fantasy). The property is `null` when NVRAM is not avaialable. |

#### Methods

| Signature | Description |
|-----------|-------------|
| start() | Starts emulator. |
| stop() | Stops emulator. |
| step() | Forces emulator to render one frame. |
| power() | HW reset (NES power button). |
| reset() | SW reset (NES reset button). |

``` javascript
const nes = cfxnes();

nes.region = 'pal'; // Set PAL region
nes.speed = 1.5; // Set 1.5x emulation speed

nes.running; // false
nes.start(); // Start emulator
nes.running; // true
nes.stop(); // Stop emulator
nes.running; // false

nes.step() // Render one frame

nes.power(); // HW reset
nes.reset(); // SW reset

if (nvram.data) {
  nvram.data.fill(0); // Clear NVRAM of the currently running game
}
```

## nes.rom

Module that can load ROM images into emulator.

Supported ROM image formats are [iNES](http://wiki.nesdev.com/w/index.php/INES) and [NES 2.0](http://wiki.nesdev.com/w/index.php/NES_2.0). cfxnes can also load zipped ROM image when [JSZip library](https://github.com/Stuk/jszip) (2.6.0 or compatible) is present. JSZip can be provided either through global variable `window.JSZip` or using `JSZip` initialization option.

``` javascript
cfxnes({JSZip});
```

ROM image can be loaded in two ways:

1. Use `rom` initialization option. This will load ROM image from the specified source and then automatically starts execution. All loading errors will be logged using `console.error`.
2. Call `nes.rom.load()` method. This allows more precise control over the loading process.

``` javascript
// 1. Use 'rom' initialization option
const nes = cfxnes({rom: source});

// 2. Call nes.rom.load() method
nes.rom.load(source)
  .then(() => {/* handle success */})
  .catch(error => {/* handle error */})
```

The source can be `Uint8Array`, `ArrayBuffer`, `Array`, `Blob` or `string`. String value is interpreted as URL of a ROM image.

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| loaded | `boolean` | no | `false` | `true` when a ROM image is loaded, `false` otherwise.  |
| sha1  | `string` | no | `null` | SHA-1 of the loaded ROM image, `null` otherwise. |

#### Methods

| Signature | Returns | Description |
|-----------|---------|-------------|
| load(source) | `Promise` | Loads ROM image from the specified source. |
| unload() || Unloads the current ROM image. |


``` javascript
const nes = cfxnes();
const {rom} = nes;

rom.loaded; // false
rom.sha1; // null

// Load ROM image from relative URL
rom.load('roms/game.nes').then(() => {
  rom.loaded; // true
  rom.sha1; // SHA-1 of the loaded ROM
  rom.unload(); // Unload the ROM
  rom.loaded; // false;
}).catch(error => {
  console.error('Oops!', error);
})

// Load ROM image from memory or blob
var data = receiveData(); // Uint8Array, ArrayBuffer, Array, Blob
rom.load(data).then(/* ... */);
```

## nes.video

Display settings module.

Cfxnes requires a `canvas` element to render its video output. The canvas can be specified in several ways:

1. Create canvas element with `cfxnes` ID. It will be automatically used during cfxnes initialization.
2. Use `video.output` initialization option.
3. Use `nes.video.output` property.

``` html
<canvas id="cfxnes"><canvas>
<script>
  const canvas = document.getElementById('cfxnes');

  // 1. There is canvas element with 'cfxnes' ID.
  let nes = cfxnes();
  nes.video.output === canvas; // true

  // 2. Use 'video.output' initialization option.
  nes = cfxnes({
    video: {output: canvas}
  });

  // 3. Use 'nes.video.output' property
  nes.video.output = canvas;
</script>
```

In case there is no ROM image loaded, running emulator will display white noise as its video output.

Once the output is set it is not possible to change `renderer`. To change renderer, you need to use a different canvas with unitialized context (see example bellow).

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| output | `HTMLCanvasElement` | yes | `null` | Canvas element used to render emulator video output. The property can be set to `null` to disable rendering. |
| renderer | `string` | yes | `'webgl'` | Rendering back-end.<br>`'canvas'` - Rendering using Canvas API. It is used as fallback when WebGL is not available.<br>`'webgl'` - Rendering using WebGL. WebGL is typically faster than the `'canvas'` renderer, but this highly depends on browser, OS, graphic card driver, etc. |
| palette | `string` | yes | `'fceux'` | Palette used for generating RGB color values. Allowed values are:<br>`'asq-real-a'`, `'asq-real-b'`,<br>`'bmf-fin-r2'`, `'bmf-fin-r3'`,<br>`'fceu-13'`, `'fceu-15'`, `'fceux'`,<br>`'nestopia-rgb'`, `'nestopia-yuv'`<br>See [FCEUX documentation](http://www.fceux.com/web/help/fceux.html?PaletteOptions.html) for their description. |
| scale | `number` | yes | `1` | Canvas resolution multiplier. It must be larger than 0. Non-integer value might cause visual artifacts due to upscaling. The base resolution is 256x240.
| maxScale | `number` | no || The largest value of the `scale` property that does not cause canvas to overgrow `window.innerWidth`, `window.innerHeight`. |
| smoothing | `boolean` | yes | `false` | Enables smoothing effect for upscaled canvas resolution. |
| debug | `boolean` | yes | `false` | Enables additional video output (content of pattern tables and background/sprite palettes) to be rendered on canvas. This will also double width of the canvas. |

``` javascript
const nes = cfxnes();
const {video} = nes;


video.renderer = 'webgl'; // Renderer can be only changed before the output is set
video.output = document.getElementById('canvas-id'); // Set output
video.palette = 'nestopia-rgb'; // Set palette
video.scale = video.maxScale; // Set scale to max. value
video.smoothing = true; // Enable smoothing
video.debug = true; // Enable debug ouput

// To change renderer, we need a different canvas with unitialized context
video.output = null; // Disconnect the current canvas
video.renderer = 'canvas'; // Change the renderer
video.output = document.getElementById('another-canvas-id'); // Use a differnt canvas
```

## nes.fullscreen

Fullscreen module.

It's recommended to wrap used `canvas` element in extra `div` to make fullscreen working properly.

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| is | `boolean` | no | false | `true` when the emulator is in fullscreen mode, `false` otherwise. |
| type | `string` | yes | `'maximized'` | Type of fullscreen mode.<br>`'maximized'` - Maximizes the output resolution while keeping its original aspect ratio.<br>`'normalized'` - Same as the `'maximazed'` type, but the output resolution is integer multiple of the base resolution 256x240. This should reduce visual artifacts caused by resolution upscaling.<br>`'stretched'` - Output is stretched to fill the whole screen (both horizontally and vertically). The original aspect ratio is not preserved.|

#### Methods

| Signature | Returns | Description |
|-----------|---------|-------------|
| enter() | `Promise` | Switches to fullscreen mode. The method does nothing when fullscreen is on. |
| exit() | `Promise` | Returns from fullscreen mode. The method does nothing when fullscreen is off. |

``` javascript
const nes = cfxnes();
const {fullscreen} = nes;

fullscreen.is; // false
fullscreen.type = 'stretched'; // Make fullscreen 'stretched'

// Note: Due to security reasons, browsers typically block fullscreen
//       requests that are not tied to user input (e.g., button click).
fullscreen.enter().then(() => {
  fullscreen.is; // true
}).catch(error => {
  console.error('Oops!', error); // Browser refused fullscreen request
});
```

## nes.audio

Audio settings module.

The `nes.audio` property is `null` when the browser does not support Web Audio (currently only IE 11 and older).

#### Properties

| Name | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| enabled | `boolean` | yes | true | `true` when audio output is enabled, `false` otherwise. |
| volume | `object` | no || Audio volume configuration. |
| volume.master | `number` | yes | `0.5` | Master volume. |
| volume.pulse1 | `number` | yes | `1` | Volume of pulse #1 channel. |
| volume.pulse2 | `number` | yes | `1` | Volume of pulse #2 channel. |
| volume.triangle | `number` | yes | `1` | Volume of triangle channel. |
| volume.noise | `number` | yes | `1` | Volume of noise channel. |
| volume.dmc | `number` | yes | `1` | Volume of DMC channel. |

``` javascript
const nes = cfxnes();
const {audio} = nes;

if (audio) {
  audio.enabled = false; // Disable audio
  audio.volume.master = 1; // Maximize the overall volume
  audio.volume.dmc = 0; // Mute the DMC channel
} else {
  console.log('Web Audio not supported!');
}
```

## nes.devices

Module that allows to set up input devices.

NES has 2 input ports, each of them can be assigned a device through numeric property. Allowed values are:
- `'joypad'` - Standard NES controller
- `'zapper'` - Zapper (beam gun)
- `null` - No device

#### Properties

| Number | Type | Writable | Default | Description |
|------|------|----------|---------|-------------|
| 1 | `string` | yes | `'joypad'` | Device connected to the port #1. |
| 2 | `string` | yes | `'zapper'` | Device connected to the port #2. |

``` javascript
const nes = cfxnes();
const {devices} = nes;

devices[1] = 'zapper'; // Set zapper on port #1
devices[2] = null; // Make port #2 empty
```

## nes.inputs

Module that allows to set up input controls.

There are 2 kinds of input devices:

1. The ones being emulated (see `nes.devices` section). We will refer to them as **devices**.
2. The real ones (keyboard, mouse, gamepad, etc.). We will refer to them as **sources**.

Input of any **device** can be expressed as a string `'<port>.<device>.<name>'`:
- `<port>` - the port number (`1` or `2`)
- `<device>` - the device (`'joypad'` or `'zapper'`)
- `<name>` - name of the input

Input of any **source** can be expressed as a string `'<source>.<name>'`:
- `<source>` - the source (`'keyboard'`, `'mouse'`, `'gamepad0'`, `'gamepad1'`, ...)
- `<name>` - name of the input

Examples:

- `'1.joypad.start'` - Start button of a joypad connected to the port #1.
- `'2.zapper.trigger'` - Trigger button of a zapper connected to the port #2.
- `'keyboard.ctrl'` - Ctrl key.
- `'mouse.left'` - Left mouse button.
- `'gamepad0'.start` - Start button of gamepad #0.
- `'gamepad1'.x` - X button of gamepad #1.

#### Methods

| Signature | Description |
|-----------|--------------|
| set(mapping) | Sets new mapping of inputs. |
| set(devInput,&nbsp;srcInputs) | Maps device input to one or more source inputs. `srcInputs` can be either an input or array of inputs. |
| get() | Returns mapping of all inputs. |
| get(input) | Returns mapping for a specific input. |
| delete(...inputs) | Deletes mapping for the specified inputs. Calling the method without any argument will delete mapping of all inputs. |
| record(callback) | Registers a callback function that will be called when the next source input is received. The callback is immediately dropped after its use. Typical use of this method is to let users customize key bindings. |

``` javascript
const nes = cfxnes();
const {inputs} = nes;

// Map inputs
inputs.set('1.joypad.a', 'keyboard.z'); // 1) Map 'A button' of joypad on port #1 to 'Z' key
inputs.set('1.joypad.a', 'keyboard.y'); // 2) Map the same input to 'Y' key
inputs.set('1.joypad.a', ['keyboard.z', 'keyboard.y']); // 1) and 2) using one call

// Override existing mapping with a new one
inputs.set({
  '1.joypad.a': ['keyboard.z', 'keyboard.y'],
  '1.joypad.b': 'keyboard.x',
});

// Query mapping
inputs.get('1.joypad.a'); // Returns ['keyboard.z', 'keyboard.y']
inputs.get('keyboard.z'); // Returns ['1.joypad.a']
inputs.get(); // Returns {'1.joypad.a': ['keyboard.z', 'keyboard.y'], '1.joypad.b': ['keyboard.x']}

// Delete mapping
inputs.get('1.joypad.a');    // Returns ['keyboard.z', 'keyboard.y']
inputs.delete('keyboard.z'); // Delete mapping for the 'Y' key
inputs.get('1.joypad.a');    // Returns ['keyboard.z']
inputs.delete();             // Delete mapping of all inputs
inputs.get('1.joypad.a');    // Returns []

// We can let user to customize controls
const devInput = '1.joypad.a';
showUserMessage('Press any key or button...');
inputs.record(srcInput => {
  inputs.delete(devInput, srcInput); // Delete previous mapping of inputs
  inputs.set(devInput, srcInput); // Map inputs
  hideUserMessage();
})
```

#### Joypad Inputs

| Input | Name |
|------|-------|
| A, B buttons | `'a'`, `'b'` |
| Start, Select buttons | `'start'`, `'select'` |
| D-pad buttons | `'left'`, `'right'`, `'up'`, `'down'` |

#### Zapper Inputs

| Input | Name |
|------|-------|
| Trigger | `'trigger'` |
| Beam position | *It is permanently mapped to mouse cursor position.* |

#### Keyboard Inputs

| Input | Name |
|------|-------|
| Character&nbsp;keys&nbsp;(letters) | `'a'`, `'b'`, ..., `'z'` |
| Character&nbsp;keys&nbsp;(numbers) | `'0'`, `'1'`, ..., `'9'` |
| Character&nbsp;keys&nbsp;(special) | `'space'`, `','`, `'.'`, `'/'`, `';'`, `'\''`, `'\\'`, `'['`, `']'`, `'``'`, `'-'`, `'='` |
| Function keys | `'f1'`, `'f2'`, ..., `'f12'` |
| Modifier keys | `'shift'`, `'ctrl'`, `'alt'` |
| Navigation keys | `'left'`, `'up'`, `'right'`, `'down'`, `'tab'`, `'home'`, `'end'`, `'page-up'`, `'page-down'` |
| System keys | `'escape'`, `'pause'` |
| Editing keys | `'enter'`, `'backspace'`, `'insert'`, `'delete'` |
| Lock keys |  `'caps-lock'`, `'num-lock'`, `'scroll-lock'` |
| Numeric keypad |  `'numpad-0'`, `'numpad-1'`, ..., `'numpad-9'`, `'add'`, `'subtract'`, `'multiply'`, `'divide'`, `'decimal-point'` |

#### Mouse Inputs

| Input | Name |
|------|-------|
| Left, middle, right button | `'left'`, `'middle'`, `'right'` |

#### Gamepad Inputs

The set of inputs that are received from a gamepad depends on whether browser is able to recognize gamepad layout. If the gamepad is correctly recognized, the [standard layout](https://w3c.github.io/gamepad/#remapping) is used. Otherwise the *generic layout* is used as fallback.

##### Standard Gamepad Layout

![standard layout](https://upload.wikimedia.org/wikipedia/commons/2/2c/360_controller.svg)

| Input | Name |
|------|-------|
| A, B, X, Y buttons | `'a'`, `'b'`, `'x'`, `'y'` |
| Back, Start, Guide buttons | `'back'`, `'start'`, `'guide'` |
| D-pad | `'dpad-up'`, `'dpad-down'`, `'dpad-left'`, `'dpad-right'` |
| Triggers | `'left-trigger'`, `'right-trigger'` |
| Bumpers | `'left-bumper'`, `'right-bumper'` |
| Sticks (buttons) | `'left-stick'`, `'right-stick'` |
| Sticks (axes) | `'left-stick-x'`, `'left-stick-y'`, `'right-stick-x'`, `'right-stick-y'`|

To specify axis direction, `'+'` or `'-'` must be appended (e.g., `'left-stick-x-'`, `'left-stick-x+'`).

##### Generic Gamepad Layout

| Input | Name |
|------|-------|
| Buttons | `'button-0'`, `'button-1'`, ... |
| Axes | `'axis-0'`, `'axis-1'`, ... |

To specify axis direction, `'+'` or `'-'` must be appended (e.g., `'axis-0-'`, `'axis-0+'`).

## nes.config

Module that provides access to emulator configuration.

The structure of configuration options corresponds to structure of initialization options (see `cfxnes` function description) with exception of `rom`, `JSZip`, `video.output` that are ignored.

| Signature | Description |
|-----------|--------------|
| get() | Returns all options and their values. |
| set(options) | Sets values of the specified options. |

``` javascript
const nes = cfxnes();
const {config} = nes;

// Get current configuration
nes.speed = 1;
nes.audio.enabled = true;
const options = config.get();
options.speed; // 1
options.audio.enabled; // true

// Restore configuration
nes.speed = 2;
nes.audio.enabled = false;
config.set(options);
nes.speed; // 1
nes.audio.enabled; // true
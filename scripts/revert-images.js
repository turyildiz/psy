const { createClient } = require('@supabase/supabase-js');
require('fs').readFileSync('.env.local', 'utf8').split('\n').forEach(l => {
  const [k, v] = l.split('=');
  if (k && v) process.env[k.trim()] = v.trim();
});

const s = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const p = (seed, w, h) => `https://picsum.photos/seed/${seed}/${w || 960}/${h || 1200}`;

const updates = [
  { title: 'Cosmic Cargo Pants',            images: [p('cargo1244'), p('cargo1244b')] },
  { title: 'Mandala Print Tee',             images: [p('tee8833'), p('tee8834')] },
  { title: 'Fractal Geometry Hoodie',       images: [p('hood9921'), p('hood9922')] },
  { title: 'UV Reactive Hoodie',            images: [p('uv7711'), p('uv7712')] },
  { title: 'Tribal Wrap Dress',             images: [p('dress5501'), p('dress5502')] },
  { title: 'Psydelic Flow Jacket',          images: [p('jack4401'), p('jack4402')] },
  { title: 'Sacred Patchwork Jacket',       images: [p('patch3301'), p('patch3302')] },
  { title: 'Shaman Cloak',                  images: [p('cloak2201'), p('cloak2202')] },
  { title: 'Flow Arts Leggings',            images: [p('legs1101'), p('legs1102')] },
  { title: 'Festival Kimono',               images: [p('kimo6601'), p('kimo6602')] },
  { title: 'Amethyst Pendant',              images: [p('jewel8810'), p('jewel8811'), p('jewel8812')] },
  { title: 'Handpan Drum — D Minor',        images: [p('handpan111'), p('handpan112')] },
  { title: 'Moog Grandmother Semi-Modular', images: [p('synth004'), p('synth004b')] },
  { title: 'Elektron Digitakt',             images: [p('ctrl005'), p('ctrl005b')] },
  { title: 'Roland DJ-707M Controller',     images: [p('ctrl002'), p('ctrl002b')] },
  { title: 'Korg Minilogue XD',             images: [p('synth001'), p('synth001b')] },
  { title: 'Focusrite Scarlett 2i2 Studio', images: [p('iface003'), p('iface003b')] },
  { title: 'Boss RE-202 Space Echo',        images: [p('pedal006'), p('pedal006b')] },
  { title: 'Native Instruments Maschine+',  images: [p('ctrl007'), p('ctrl007b')] },
  { title: 'Strymon BigSky Reverb Pedal',   images: [p('pedal008'), p('pedal008b')] },
];

Promise.all(updates.map(row => s.from('listings').update({ images: row.images }).eq('title', row.title)))
  .then(results => {
    const errors = results.filter(r => r.error);
    console.log(errors.length ? 'Errors: ' + errors.map(r => r.error?.message).join(', ') : `Reverted ${updates.length} listings to working picsum images`);
  });

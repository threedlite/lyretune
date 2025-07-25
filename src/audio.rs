use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{FromSample, Sample, SizedSample};
use num_complex::Complex;
use rustfft::{FftPlanner, num_traits::Zero};
use std::sync::{Arc, Mutex};

#[derive(Clone, Debug)]
pub struct AudioState {
    pub frequency_data: Vec<f32>,
    pub peak_frequency: f32,
    pub sample_rate: u32
}

impl Default for AudioState {
    fn default() -> Self {
        Self {
            frequency_data: vec![0.0; 16384],
            peak_frequency: 0.0,
            sample_rate: 44100,
        }
    }
}

pub fn start_audio_processing(audio_state: Arc<Mutex<AudioState>>) {
    let host = cpal::default_host();
    let device = host.default_input_device().expect("No input device available");
    
    let config = device.default_input_config().expect("Failed to get default input config");
    let sample_rate = config.sample_rate().0;
    
    {
        let mut state = audio_state.lock().unwrap();
        state.sample_rate = sample_rate;
    }
    
    let sample_format = config.sample_format();
    let config: cpal::StreamConfig = config.into();
    
    match sample_format {
        cpal::SampleFormat::F32 => run::<f32>(&device, config, audio_state),
        cpal::SampleFormat::I16 => run::<i16>(&device, config, audio_state),
        cpal::SampleFormat::U16 => run::<u16>(&device, config, audio_state),
        _ => panic!("Unsupported sample format '{sample_format}'"),
    }
}

fn run<T>(device: &cpal::Device, config: cpal::StreamConfig, audio_state: Arc<Mutex<AudioState>>)
where
    T: Sample<Float = f32> + SizedSample,
    f32: FromSample<T>,
{
    let channels = config.channels as usize;
    let fft_size = 32768;
    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(fft_size);
    
    let mut input_buffer = vec![Complex::zero(); fft_size];
    let mut output_buffer = vec![Complex::zero(); fft_size];
    let mut sample_buffer = Vec::new();
    
    let stream = device.build_input_stream(
        &config,
        move |data: &[T], _: &cpal::InputCallbackInfo| {
            for sample in data.chunks(channels) {
                let mono_sample: f32 = sample[0].to_float_sample();
                sample_buffer.push(mono_sample);
                
                if sample_buffer.len() >= fft_size {
                    for (i, &sample) in sample_buffer.iter().take(fft_size).enumerate() {
                        input_buffer[i] = Complex::new(sample * hamming_window(i, fft_size), 0.0);
                    }
                    
                    output_buffer.copy_from_slice(&input_buffer);
                    fft.process(&mut output_buffer);
                    
                    let frequency_data: Vec<f32> = output_buffer.iter()
                        .take(fft_size / 2)
                        .map(|c| c.norm())
                        .collect();
                    
                    let peak_index = frequency_data.iter()
                        .enumerate()
                        .max_by(|(_, a), (_, b)| a.partial_cmp(b).unwrap())
                        .map(|(index, _)| index)
                        .unwrap_or(0);
                    
                    let peak_frequency = index_to_frequency(peak_index, config.sample_rate.0, fft_size);
                    
                    if let Ok(mut state) = audio_state.lock() {
                        state.frequency_data = frequency_data;
                        state.peak_frequency = peak_frequency;
                    }
                    
                    sample_buffer.clear();
                }
            }
        },
        move |err| eprintln!("An error occurred on the audio stream: {}", err),
        None,
    ).expect("Failed to build input stream");
    
    stream.play().expect("Failed to play stream");
    
    std::thread::park();
}

fn hamming_window(i: usize, size: usize) -> f32 {
    0.54 - 0.46 * (2.0 * std::f32::consts::PI * i as f32 / (size - 1) as f32).cos()
}

pub fn play_notes_descending(frequencies: &[f32]) {
    std::thread::spawn({
        let frequencies = frequencies.to_vec();
        move || {
            let _ = play_notes_descending_internal(&frequencies);
        }
    });
}

fn play_notes_descending_internal(frequencies: &[f32]) -> Result<(), cpal::PlayStreamError> {
    let host = cpal::default_host();
    let device = host.default_output_device().ok_or_else(|| {
        eprintln!("No output device available");
        cpal::PlayStreamError::DeviceNotAvailable
    })?;
    
    let config = device.default_output_config().map_err(|e| {
        eprintln!("Failed to get default output config: {}", e);
        cpal::PlayStreamError::DeviceNotAvailable
    })?;
    
    let sample_rate = config.sample_rate().0 as f32;
    let channels = config.channels() as usize;
    
    // Play each frequency in descending order
    for &freq in frequencies.iter().rev() {
        let duration = 0.64; // 640ms per note (20% faster than 800ms)
        let _samples_per_note = (sample_rate * duration) as usize;
        
        let mut sample_clock = 0f32;
        let mut next_value = move || {
            sample_clock = (sample_clock + 1.0) % sample_rate;
            let time = sample_clock / sample_rate;
            let amplitude = 0.2; // Slightly quieter base volume
            
            // Lyre-like pluck envelope: sharp attack, then quick decay with sustain
            let envelope = if time < 0.003 {
                // Very sharp attack (3ms) - more pluck-like
                (time / 0.003) * 1.5 // Initial spike
            } else if time < 0.05 {
                // Quick initial decay
                1.5 * (-time * 15.0).exp() 
            } else {
                // Longer sustain with slower decay (metallic resonance)
                0.4 * (-time * 1.5).exp()
            };
            
            // Lyre-specific harmonics: more metallic, less piano-like
            let fundamental = (freq * 2.0 * std::f32::consts::PI * time).sin();
            
            // Add slight detuning for metallic character
            let detune1 = (freq * 1.003 * 2.0 * std::f32::consts::PI * time).sin();
            let detune2 = (freq * 0.997 * 2.0 * std::f32::consts::PI * time).sin();
            
            // Harmonics with different weights for lyre-like timbre
            let harmonic2 = 0.4 * (freq * 2.0 * 2.0 * std::f32::consts::PI * time).sin(); // Strong octave
            let harmonic3 = 0.15 * (freq * 3.0 * 2.0 * std::f32::consts::PI * time).sin(); // Less perfect fifth
            let harmonic5 = 0.08 * (freq * 5.0 * 2.0 * std::f32::consts::PI * time).sin(); // Add 5th harmonic
            let harmonic7 = 0.05 * (freq * 7.0 * 2.0 * std::f32::consts::PI * time).sin(); // Add 7th harmonic
            
            // Add some high-frequency metallic "zing"
            let metallic_zing = 0.03 * (freq * 11.0 * 2.0 * std::f32::consts::PI * time).sin() * (-time * 8.0).exp();
            
            // Combine for metallic string sound
            let complex_wave = fundamental * 0.7 + 
                             (detune1 + detune2) * 0.1 +
                             harmonic2 + harmonic3 + harmonic5 + harmonic7 + 
                             metallic_zing;
            
            amplitude * envelope * complex_wave
        };
        
        let err_fn = |err| eprintln!("An error occurred on stream: {}", err);
        
        let stream = match config.sample_format() {
            cpal::SampleFormat::F32 => device.build_output_stream(
                &config.config(),
                move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                    for frame in data.chunks_mut(channels) {
                        let value = next_value();
                        for sample in frame.iter_mut() {
                            *sample = value;
                        }
                    }
                },
                err_fn,
                None,
            ),
            cpal::SampleFormat::I16 => device.build_output_stream(
                &config.config(),
                move |data: &mut [i16], _: &cpal::OutputCallbackInfo| {
                    for frame in data.chunks_mut(channels) {
                        let value = next_value();
                        let value = i16::from_sample(value);
                        for sample in frame.iter_mut() {
                            *sample = value;
                        }
                    }
                },
                err_fn,
                None,
            ),
            cpal::SampleFormat::U16 => device.build_output_stream(
                &config.config(),
                move |data: &mut [u16], _: &cpal::OutputCallbackInfo| {
                    for frame in data.chunks_mut(channels) {
                        let value = next_value();
                        let value = u16::from_sample(value);
                        for sample in frame.iter_mut() {
                            *sample = value;
                        }
                    }
                },
                err_fn,
                None,
            ),
            sample_format => {
                eprintln!("Unsupported sample format '{sample_format}'");
                return Err(cpal::PlayStreamError::DeviceNotAvailable);
            }
        };
        
        match stream {
            Ok(stream) => {
                stream.play()?;
                std::thread::sleep(std::time::Duration::from_millis((duration * 1000.0) as u64));
                drop(stream);
            }
            Err(e) => {
                eprintln!("Failed to build output stream: {}", e);
                return Err(cpal::PlayStreamError::DeviceNotAvailable);
            }
        }
        
        // Very small pause between notes (lyre strings ring into each other)
        std::thread::sleep(std::time::Duration::from_millis(100));
    }
    
    Ok(())
}

fn index_to_frequency(index: usize, sample_rate: u32, fft_size: usize) -> f32 {
    index as f32 * sample_rate as f32 / (fft_size as f32)
}
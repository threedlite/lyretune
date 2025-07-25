use crate::audio::{AudioState, play_notes_descending};
use crate::scales::{ScaleType, Mode, Genus, Temperament, ScaleData, get_string_count_defaults};
use eframe::egui;
use egui_plot::{Plot, Line};
use std::sync::{Arc, Mutex};
use std::time::Instant;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum NoteFilter {
    TonesOnly,
    TonesAndSemitones,
    All,
}

pub struct UiState {
    pub num_strings: usize,
    pub first_note: String,
    pub scale_type: ScaleType,
    pub mode: Mode,
    pub genus: Genus,
    pub temperament: Temperament,
    pub octave_offset: i32,
    pub zoom: f32,
    pub tolerance: f32,
    pub show_full_spectrum: bool,
    pub scale_data: ScaleData,
    pub note_hits: Vec<Instant>,
    pub note_filter: NoteFilter,
    pub magnitude_scale: f32,
}

impl Default for UiState {
    fn default() -> Self {
        let num_strings = 7;
        let (mode, zoom) = get_string_count_defaults(num_strings);
        
        Self {
            num_strings,
            first_note: "E".to_string(),
            scale_type: ScaleType::Modes,
            mode,
            genus: Genus::Diatonic,
            temperament: Temperament::JustAncient,
            octave_offset: 0,
            zoom,
            tolerance: 1.5,
            show_full_spectrum: false,
            scale_data: ScaleData::new(
                ScaleType::Modes,
                Some(mode),
                None,
                "E",
                num_strings,
                Temperament::JustAncient,
                0,
            ),
            note_hits: vec![Instant::now(); 24],
            note_filter: NoteFilter::TonesOnly,
            magnitude_scale: 30.0,
        }
    }
}

pub fn show(ui_state: &mut UiState, audio_state: &Arc<Mutex<AudioState>>, ctx: &egui::Context) {
    egui::CentralPanel::default()
        .frame(egui::Frame::default().fill(egui::Color32::BLACK))
        .show(ctx, |ui| {
        ui.horizontal(|ui| {
            ui.heading("LyreTune - Ancient Greek Lyre Tuner");
            ui.with_layout(egui::Layout::right_to_left(egui::Align::TOP), |ui| {
                ui.label(format!("v{}", env!("CARGO_PKG_VERSION")));
            });
        });
        
        ui.separator();
        
        ui.horizontal(|ui| {
            ui.label("Number of strings:");
            if ui.add(egui::Slider::new(&mut ui_state.num_strings, 4..=24)).changed() {
                let (mode, zoom) = get_string_count_defaults(ui_state.num_strings);
                ui_state.mode = mode;
                ui_state.zoom = zoom;
                
                // If switching away from 4 strings and currently using Phorminx, switch to Modes
                if ui_state.num_strings != 4 && ui_state.scale_type == ScaleType::Phorminx {
                    ui_state.scale_type = ScaleType::Modes;
                }
                
                update_scale_data(ui_state);
            }
            
            ui.separator();
            
            ui.label("First note:");
                     
            egui::ComboBox::from_id_salt("first_note_combo")
                .selected_text(&ui_state.first_note)
                .show_ui(ui, |ui| {
                    // All semitones and quartertones
                    let all_notes = [
                        "C", "C*", "C#", "C#*", 
                        "D", "D*", "D#", "D#*",
                        "E", "E*", 
                        "F", "F*", "F#", "F#*",
                        "G", "G*", "G#", "G#*",
                        "A", "A*", "A#", "A#*",
                        "B", "B*"
                    ];
                    
                    for note in all_notes {
                        let should_show = match ui_state.note_filter {
                            NoteFilter::TonesOnly => !note.contains('#') && !note.contains('*'),
                            NoteFilter::TonesAndSemitones => !note.contains('*'),
                            NoteFilter::All => true,
                        };
                        
                        if should_show {
                            if ui.selectable_value(&mut ui_state.first_note, note.to_string(), note).changed() {
                                update_scale_data(ui_state);
                            }
                        }
                    }
                });
        });
        
        ui.separator();
        
        ui.horizontal(|ui| {
            ui.label("Tuning system:");
            egui::ComboBox::from_id_salt("scale_type_combo")
                .selected_text(format!("{:?}", ui_state.scale_type))
                .show_ui(ui, |ui| {
                    if ui.selectable_value(&mut ui_state.scale_type, ScaleType::Modes, "Ancient Greek Modes").changed() {
                        update_scale_data(ui_state);
                    }
                    if ui.selectable_value(&mut ui_state.scale_type, ScaleType::Genres, "Ancient Greek Genres").changed() {
                        update_scale_data(ui_state);
                    }
                    if ui.selectable_value(&mut ui_state.scale_type, ScaleType::Pentatonic, "Pentatonic").changed() {
                        update_scale_data(ui_state);
                    }
                    if ui.selectable_value(&mut ui_state.scale_type, ScaleType::DoubleHarmonic, "Double Harmonic").changed() {
                        update_scale_data(ui_state);
                    }
                    // Only show Phorminx option when 4 strings is selected
                    if ui_state.num_strings == 4 {
                        if ui.selectable_value(&mut ui_state.scale_type, ScaleType::Phorminx, "Phorminx").changed() {
                            update_scale_data(ui_state);
                        }
                    }
                });
            
            ui.separator();
            
            match ui_state.scale_type {
                ScaleType::Modes => {
                    ui.label("Mode:");
                    let mode_labels = [
                        (Mode::Mixolydios, "Mixolydios (modern Locrian)"),
                        (Mode::Hypodorios, "Hypodorios/Locrian (modern Aeolian)"),
                        (Mode::Lydios, "Lydios (modern Ionian)"),
                        (Mode::Phrygios, "Phrygios (modern Dorian)"),
                        (Mode::Dorios, "Dorios (modern Phrygian)"),
                        (Mode::Hypolydios, "Hypolydios (modern Lydian)"),
                        (Mode::Hypophrygios, "Hypophrygios (modern Mixolydian)"),
                    ];
                    
                    let current_mode_label = mode_labels.iter()
                        .find(|(mode, _)| *mode == ui_state.mode)
                        .map(|(_, label)| *label)
                        .unwrap_or("Unknown");
                    
                    egui::ComboBox::from_id_salt("mode_combo")
                        .selected_text(current_mode_label)
                        .show_ui(ui, |ui| {
                            for (mode, label) in mode_labels {
                                if ui.selectable_value(&mut ui_state.mode, mode, label).changed() {
                                    update_scale_data(ui_state);
                                }
                            }
                        });
                }
                ScaleType::Genres => {
                    ui.label("Genus:");
                    egui::ComboBox::from_id_salt("genus_combo")
                        .selected_text(format!("{:?}", ui_state.genus))
                        .show_ui(ui, |ui| {
                            for genus in [Genus::Diatonic, Genus::Chromatic, Genus::Enharmonic] {
                                if ui.selectable_value(&mut ui_state.genus, genus, format!("{:?}", genus)).changed() {
                                    update_scale_data(ui_state);
                                }
                            }
                        });
                }
                _ => {}
            }
            
            ui.separator();
            
            ui.label("Temperament:");
            let temperament_labels = [
                (Temperament::Equal, "Equal"),
                (Temperament::Just, "Just (Modern)"),
                (Temperament::JustAncient, "Just (Ancient Greek/Indian)"),
                (Temperament::Meantone, "Meantone"),
            ];
            
            let current_label = temperament_labels.iter()
                .find(|(temp, _)| *temp == ui_state.temperament)
                .map(|(_, label)| *label)
                .unwrap_or("Unknown");
            
            egui::ComboBox::from_id_salt("temperament_combo")
                .selected_text(current_label)
                .show_ui(ui, |ui| {
                    for (temp, label) in temperament_labels {
                        if ui.selectable_value(&mut ui_state.temperament, temp, label).changed() {
                            update_scale_data(ui_state);
                        }
                    }
                });
            
            ui.separator();
            
            if ui.small_button("🔊").clicked() {
                play_notes_descending(&ui_state.scale_data.frequencies);
            }
        });
        
        ui.separator();
        
        let audio_data = audio_state.lock().unwrap();
        let peak_freq = audio_data.peak_frequency;
        let freq_data = audio_data.frequency_data.clone();
        let sample_rate = audio_data.sample_rate;
        drop(audio_data);
        
        ui.horizontal(|ui| {
            ui.label(format!("Peak frequency: {:.1} Hz", peak_freq));
            
            let closest_note = find_closest_note(&ui_state.scale_data, peak_freq);
            if let Some((index, target_freq)) = closest_note {
                let diff = peak_freq - target_freq;
                if diff.abs() < ui_state.tolerance {
                    ui_state.note_hits[index] = Instant::now();
                }
                
                ui.separator();
                ui.label(format!("Target: {} ({:.1} Hz)", ui_state.scale_data.notes[index], target_freq));
                
                let cents = 1200.0 * (peak_freq / target_freq).log2();
                ui.label(format!("Difference: {:.1} cents", cents));
            }
        });
        
        ui.separator();
        
        ui.label("Notes:");
        ui.horizontal(|ui| {
            for (i, (note, freq)) in ui_state.scale_data.notes.iter()
                .zip(ui_state.scale_data.frequencies.iter())
                .enumerate() 
            {
                let is_recent_hit = ui_state.note_hits[i].elapsed().as_secs() < 3;
                let color = if is_recent_hit {
                    egui::Color32::GREEN
                } else {
                    egui::Color32::YELLOW
                };
                
                ui.colored_label(color, format!("{}: {:.1}Hz", note, freq));
                ui.separator();
            }
        });
        
        ui.separator();
        
        let plot_height = 400.0;
        
        // Calculate bounds if not showing full spectrum
        let (x_min, x_max) = if !ui_state.show_full_spectrum && !ui_state.scale_data.frequencies.is_empty() {
            let min_freq = ui_state.scale_data.frequencies.iter()
                .min_by(|a, b| a.partial_cmp(b).unwrap())
                .unwrap_or(&0.0);
            let max_freq = ui_state.scale_data.frequencies.iter()
                .max_by(|a, b| a.partial_cmp(b).unwrap())
                .unwrap_or(&1000.0);
            let range = max_freq - min_freq;
            let zoomed_range = range / ui_state.zoom; // Higher zoom = smaller range
            let center = (min_freq + max_freq) / 2.0;
            let padding = zoomed_range * 0.1; // 10% padding on each side
            ((center - zoomed_range/2.0 - padding) as f64, (center + zoomed_range/2.0 + padding) as f64)
        } else {
            (0.0, sample_rate as f64 / 2.0) // Full spectrum up to Nyquist frequency
        };
        
        ui.visuals_mut().extreme_bg_color = egui::Color32::BLACK;
        
        // Calculate bounds with 20% padding for drag limits
        let freq_min = ui_state.scale_data.frequencies.iter()
            .min_by(|a, b| a.partial_cmp(b).unwrap())
            .unwrap_or(&0.0);
        let freq_max = ui_state.scale_data.frequencies.iter()
            .max_by(|a, b| a.partial_cmp(b).unwrap())
            .unwrap_or(&1000.0);
        let freq_range = freq_max - freq_min;
        let drag_min = (freq_min - freq_range * 0.2) as f64;
        let drag_max = (freq_max + freq_range * 0.2) as f64;
        
        let mut plot = Plot::new("frequency_plot")
            .height(plot_height)
            .auto_bounds([false, true].into()) // Disable x auto bounds, enable y auto bounds
            .show_background(true)
            .allow_drag([true, false]) // Enable horizontal dragging only
            .allow_scroll([true, false]) // Enable horizontal scrolling only
            .allow_zoom([true, false]) // Allow horizontal zoom only
            .show_grid(false) // Disable grid
            .clamp_grid(true); // Clamp to prevent going outside bounds
            
        // Set the clamping bounds
        if !ui_state.show_full_spectrum {
            plot = plot.set_margin_fraction(egui::Vec2::new(0.0, 0.1));
        }
        
        plot.show(ui, |plot_ui| {
            // Set bounds only if we haven't interacted with the plot
            let response = plot_ui.response();
            if !response.dragged() && !response.hovered() {
                plot_ui.set_plot_bounds(egui_plot::PlotBounds::from_min_max([x_min, 0.0], [x_max, 255.0]));
            }
            
            // Only apply clamping when not showing full spectrum and zoom >= 1
            if !ui_state.show_full_spectrum && ui_state.zoom >= 1.0 {
                let current_bounds = plot_ui.plot_bounds();
                let clamped_min = current_bounds.min()[0].max(drag_min);
                let clamped_max = current_bounds.max()[0].min(drag_max);
                if clamped_min != current_bounds.min()[0] || clamped_max != current_bounds.max()[0] {
                    plot_ui.set_plot_bounds(egui_plot::PlotBounds::from_min_max(
                        [clamped_min, 0.0], // Keep y-min fixed
                        [clamped_max, 255.0] // Keep y-max fixed
                    ));
                }
            }
            // Draw spectrum as vertical rectangles instead of a spline
            let scale_factor = ui_state.magnitude_scale;
            for (i, &magnitude) in freq_data.iter().enumerate() {
                let scaled_magnitude = magnitude * scale_factor;
                let freq = i as f64 * sample_rate as f64 / (freq_data.len() * 2) as f64;
                // Only draw rectangles within the visible range
                if freq >= x_min && freq <= x_max && scaled_magnitude > 1.0 { // Threshold to avoid noise
                    let rect_width = (sample_rate as f64 / (freq_data.len() * 2) as f64) * 0.8; // 80% of frequency bin width
                    
                    // Calculate color intensity based on magnitude (0-255 range)
                    let intensity = (scaled_magnitude.min(255.0) / 255.0 * 255.0) as u8;
                    let light_blue = egui::Color32::from_rgba_unmultiplied(
                        100 + intensity / 3, // Light red component
                        150 + intensity / 2, // Light green component  
                        255,                  // Full blue component
                        180 + intensity / 4   // Alpha varies with intensity
                    );
                    
                    // Draw a vertical line from 0 to magnitude height (scaled rectangle)
                    let points = vec![
                        [freq, 0.0],
                        [freq, scaled_magnitude as f64]
                    ];
                    plot_ui.line(Line::new(points)
                        .color(light_blue)
                        .width((rect_width * (x_max - x_min) / 1000.0).max(2.0) as f32)); // Minimum width of 2
                }
            }
            
            // First draw all vertical lines
            for (i, &freq) in ui_state.scale_data.frequencies.iter().enumerate() {
                let is_recent_hit = ui_state.note_hits[i].elapsed().as_secs() < 3;
                let line_color = if is_recent_hit {
                    egui::Color32::GREEN
                } else {
                    egui::Color32::YELLOW
                };
                plot_ui.vline(egui_plot::VLine::new(freq as f64)
                    .color(line_color)
                    .width(2.0));
            }
            
            // Then draw note labels on top of lines
            for (note, &freq) in ui_state.scale_data.notes.iter()
                .zip(ui_state.scale_data.frequencies.iter()) 
            {
                plot_ui.text(
                    egui_plot::Text::new(
                        egui_plot::PlotPoint::new(freq as f64, 240.0), // Position near top of plot
                        egui::RichText::new(note)
                            .size(24.0) // Make text twice as big
                            .color(egui::Color32::WHITE)
                            .background_color(egui::Color32::BLACK) // Black background
                    )
                    .anchor(egui::Align2::CENTER_BOTTOM)
                    .highlight(true)
                );
            }
        });
        
        ui.separator();
        
        if ui.collapsing("Advanced Options", |ui| {
            ui.horizontal(|ui| {
                ui.label("Octave offset:");
                if ui.add(egui::Slider::new(&mut ui_state.octave_offset, -3..=3)).changed() {
                    update_scale_data(ui_state);
                }
            });
            
            ui.horizontal(|ui| {
                ui.label("Zoom:");
                ui.add(egui::Slider::new(&mut ui_state.zoom, 0.25..=4.0));
            });
            
            ui.horizontal(|ui| {
                ui.label("Tolerance (Hz):");
                ui.add(egui::Slider::new(&mut ui_state.tolerance, 0.0..=5.0));
            });
            
            ui.horizontal(|ui| {
                ui.label("Options for the first note:");
                egui::ComboBox::from_id_salt("note_filter_combo")
                    .selected_text(match ui_state.note_filter {
                        NoteFilter::TonesOnly => "Tones only",
                        NoteFilter::TonesAndSemitones => "Tones and semitones",
                        NoteFilter::All => "All (includes quartertones)",
                    })
                    .show_ui(ui, |ui| {
                        ui.selectable_value(&mut ui_state.note_filter, NoteFilter::TonesOnly, "Tones only");
                        ui.selectable_value(&mut ui_state.note_filter, NoteFilter::TonesAndSemitones, "Tones and semitones");
                        ui.selectable_value(&mut ui_state.note_filter, NoteFilter::All, "All (includes quartertones)");
                    });
            });
            
            ui.horizontal(|ui| {
                ui.label("Magnitude scale:");
                egui::ComboBox::from_id_salt("magnitude_scale_combo")
                    .selected_text(format!("{:.1}", ui_state.magnitude_scale))
                    .show_ui(ui, |ui| {
                        ui.selectable_value(&mut ui_state.magnitude_scale, 0.25, "0.25");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 0.5, "0.5");                        
                        ui.selectable_value(&mut ui_state.magnitude_scale, 1.0, "1.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 10.0, "10.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 20.0, "20.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 30.0, "30.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 40.0, "40.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 50.0, "50.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 60.0, "60.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 70.0, "70.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 80.0, "80.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 90.0, "90.0");
                        ui.selectable_value(&mut ui_state.magnitude_scale, 100.0, "100.0");
                    });
            });
            
            ui.checkbox(&mut ui_state.show_full_spectrum, "Show full spectrum");
        }).body_returned.is_some() {}
    });
}

fn update_scale_data(ui_state: &mut UiState) {
    ui_state.scale_data = ScaleData::new(
        ui_state.scale_type,
        Some(ui_state.mode),
        Some(ui_state.genus),
        &ui_state.first_note,
        ui_state.num_strings,
        ui_state.temperament,
        ui_state.octave_offset,
    );
}

fn find_closest_note(scale_data: &ScaleData, frequency: f32) -> Option<(usize, f32)> {
    scale_data.frequencies.iter()
        .enumerate()
        .min_by_key(|(_, &f)| ((f - frequency).abs() * 1000.0) as i32)
        .map(|(i, &f)| (i, f))
}
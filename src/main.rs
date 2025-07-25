mod audio;
mod scales;
mod ui;

use eframe::egui;
use std::sync::{Arc, Mutex};

#[derive(Default)]
pub struct LyreTuneApp {
    audio_state: Arc<Mutex<audio::AudioState>>,
    ui_state: ui::UiState,
}

impl LyreTuneApp {
    pub fn new(cc: &eframe::CreationContext<'_>) -> Self {
        cc.egui_ctx.set_theme(egui::Theme::Dark);
        
        let audio_state = Arc::new(Mutex::new(audio::AudioState::default()));
        let audio_state_clone = audio_state.clone();
        
        std::thread::spawn(move || {
            audio::start_audio_processing(audio_state_clone);
        });
        
        Self {
            audio_state,
            ui_state: ui::UiState::default(),
        }
    }
}

impl eframe::App for LyreTuneApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        ui::show(&mut self.ui_state, &self.audio_state, ctx);
        ctx.request_repaint_after(std::time::Duration::from_millis(50));
    }
}

fn main() -> eframe::Result<()> {
    let icon_data = include_bytes!("../icon.png");
    let icon = eframe::icon_data::from_png_bytes(icon_data).ok();
    
    let native_options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1000.0, 700.0])
            .with_title("LyreTune - Ancient Greek Lyre Tuner")
            .with_transparent(false)
            .with_icon(icon.unwrap_or_default()),
        ..Default::default()
    };
    
    eframe::run_native(
        "LyreTune",
        native_options,
        Box::new(|cc| Ok(Box::new(LyreTuneApp::new(cc)))),
    )
}
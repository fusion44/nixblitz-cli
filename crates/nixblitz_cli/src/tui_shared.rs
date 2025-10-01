use iocraft::hooks::State;
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectionStatus {
    Connecting,
    Connected,
    Disconnected,
}

#[derive(Debug, Clone, strum::Display, PartialEq)]
pub(crate) enum PopupData {
    Update,
    EngineOffHelp,
}

pub(crate) type SwitchLogsState = Arc<Mutex<State<Vec<String>>>>;
pub(crate) type ShowPopupState = Arc<Mutex<State<bool>>>;
pub(crate) type PopupDataState = Arc<Mutex<State<Option<PopupData>>>>;

import Application

/// The use cases home depends on, bundled so the presenter takes one argument.
extension HomeViewModel {
    public struct UseCases: Sendable {
        let getOverview: any GetHomeOverviewUseCase
        let completeQuest: any CompleteQuestUseCase
        let defeatBoss: any DefeatBossUseCase
        /// Deleting a moment opened to edit.
        let deleteEvent: any DeleteEventUseCase
        /// Undo right after recording: back to before the card, title included (ADR-0055 §3).
        let undoRecord: any UndoRecordUseCase
        let moments: MomentUseCases
        /// The weekly reminder offer.
        let reminder: ReminderUseCases
        /// The dad's answer to the film offer.
        let answerSagaOffer: any AnswerSagaOfferUseCase
        /// The dad closed the card for a new title.
        let markTitleSeen: any MarkTitleSeenUseCase

        public init(
            getOverview: any GetHomeOverviewUseCase,
            completeQuest: any CompleteQuestUseCase,
            defeatBoss: any DefeatBossUseCase,
            deleteEvent: any DeleteEventUseCase,
            undoRecord: any UndoRecordUseCase,
            moments: MomentUseCases,
            reminder: ReminderUseCases,
            answerSagaOffer: any AnswerSagaOfferUseCase,
            markTitleSeen: any MarkTitleSeenUseCase
        ) {
            self.getOverview = getOverview
            self.completeQuest = completeQuest
            self.defeatBoss = defeatBoss
            self.deleteEvent = deleteEvent
            self.undoRecord = undoRecord
            self.moments = moments
            self.reminder = reminder
            self.answerSagaOffer = answerSagaOffer
            self.markTitleSeen = markTitleSeen
        }
    }

    /// Everything to do with legendary moments.
    public struct MomentUseCases: Sendable {
        let capture: any CaptureMomentUseCase
        let update: any UpdateMomentUseCase
        let getPhoto: any GetPhotoUseCase

        public init(
            capture: any CaptureMomentUseCase,
            update: any UpdateMomentUseCase,
            getPhoto: any GetPhotoUseCase
        ) {
            self.capture = capture
            self.update = update
            self.getPhoto = getPhoto
        }
    }
}

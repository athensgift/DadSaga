import Application
import Localization

/// What the dad reads when exporting or importing doesn't work (ADR-0057 §8): what happened and what to do, calmly.
enum DataTransferMessages {
    /// Ends by saying the saga is as it was, as every failure in Settings does.
    static func exportFailed(_ error: any Error, strings: Strings) -> String {
        let reason = switch error {
        case is BackgroundTimeExpired:
            strings.text(
                "The export stopped when you left DadSaga. Try again whenever you like, and keep DadSaga open until it's done."
            )
        case let error where SagaCopyError(error) == .nothingToCopy: strings.text("There's nothing to export yet.")
        case let error where SagaCopyError(error) == .notEnoughSpace: notEnoughSpace(strings)
        default: strings.text("Couldn't export your data. Please try again.")
        }
        return reason + " " + sagaUnchanged(strings)
    }

    /// With a saga on this iPhone, ends by saying it is as it was; on onboarding there is none yet.
    static func importFailed(_ error: any Error, replacesSaga: Bool, strings: Strings) -> String {
        let reason = switch error {
        case is BackgroundTimeExpired:
            strings.text(
                "The import stopped when you left DadSaga. Try again whenever you like, and keep DadSaga open until it's done."
            )
        default:
            switch SagaCopyError(error) {
            case .newerFormat:
                strings.text("This copy was made by a newer version of DadSaga. Update the app, then try again.")
            case .notACopy, .incomplete, .damaged:
                strings.text("This file isn't a complete DadSaga copy. It may not have finished saving or sending.")
            case .unreadable:
                strings.text(
                    """
                    The file couldn't be opened. If it's in iCloud Drive or another cloud service, check your \
                    connection and try again.
                    """
                )
            case .notEnoughSpace: notEnoughSpace(strings)
            case .nothingToCopy, .failed: strings.text("Couldn't import the data. Please try again.")
            }
        }
        return replacesSaga ? reason + " " + sagaUnchanged(strings) : reason
    }

    private static func sagaUnchanged(_ strings: Strings) -> String {
        strings.text("Your saga hasn't changed.")
    }

    private static func notEnoughSpace(_ strings: Strings) -> String {
        strings.text("There isn't enough free space on this iPhone. Free up some space and try again.")
    }
}

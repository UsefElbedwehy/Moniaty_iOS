import UserNotifications

/// Rich-push extension. When a notification arrives with `mutable-content: 1` (set by the
/// `send-push` Edge Function) and an `image` URL in its `data` payload, this downloads the image
/// and attaches it so it renders in the notification banner. Text-only pushes pass straight
/// through unchanged.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        let content = request.content.mutableCopy() as? UNMutableNotificationContent
        bestAttempt = content

        guard let content else {
            contentHandler(request.content)
            return
        }

        // `aps.alert.subtitle` already carries this, but honor a data-payload `subtitle` too.
        if content.subtitle.isEmpty, let subtitle = request.content.userInfo["subtitle"] as? String {
            content.subtitle = subtitle
        }

        guard let urlString = request.content.userInfo["image"] as? String,
              let url = URL(string: urlString) else {
            contentHandler(content)
            return
        }

        URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
            defer { contentHandler(content) }
            guard let tempURL else { return }
            // Give the temp file an extension so iOS can infer the image type.
            let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
            let dest = tempURL.deletingPathExtension().appendingPathExtension(ext)
            try? FileManager.default.moveItem(at: tempURL, to: dest)
            if let attachment = try? UNNotificationAttachment(identifier: "image", url: dest) {
                content.attachments = [attachment]
            }
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        // The download ran out of time — deliver whatever we have (text, minus the image).
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }
}

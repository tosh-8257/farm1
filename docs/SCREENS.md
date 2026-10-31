# FARM V2 - all screens (branch v2-phase10 @ ee40a563)

Every public page widget (files containing a Scaffold) under lib/, rendered one at a time in a scratch clone with no login, against a LOCAL MOCK backend returning generic SAMPLE rows; every screenshot carries a 'SAMPLE DATA' strip. Writes return 503. Production never contacted.


## Design note: colour

Black, white and grey everywhere, plus ONE accent: classic gold `#D4AF37`, used sparingly. It is defined once as `kBrandAccent` in `lib/core/app_theme.dart`; every use reads `AppTheme.accent` (or the FlutterFlow tokens `brandAccent` / `onBrandAccent` / `brandAccentText`), so changing that constant re-themes the app.

- Where gold is used: the FARM coin mark (`FarmMark`, splash), primary buttons (Elevated/Filled theme: gold fill, black text, about 10:1), wallet balance figure on the dashboard card (gold on black, about 10:1), active nav tab/indicator (TabBar indicator, admin nav), onboarding art loop arc and tallest bar, selected chips (gold fill, black label), focus rings.
- Gold text on a light background uses `AppTheme.accentOn(background)`, a darker gold derived from the same constant that meets WCAG AA 4.5:1; fills always carry black text.
- Never gold: error, success, warning or info states, switches, checkboxes, radios, body text. Everything else stays monochrome.
- Screenshots below predate the accent.

| Sheet | Widget | Source | Status | File |
|---|---|---|---|---|
| admin | AddAdminPage | lib/pages/superadmin/add_admin_page.dart | captured | superadmin__AddAdminPage.png |
| admin | AddSuperadminPage | lib/admin/pages/add_superadmin_page.dart | captured | admin__AddSuperadminPage.png |
| admin | AdminContainer | lib/admin/pages/admin_container.dart | captured | admin__AdminContainer.png |
| admin | AdminDashboardPage | lib/admin/pages/admin_dashboard_page.dart | captured | admin__AdminDashboardPage.png |
| admin | AdminForgotPasswordPage | lib/admin/pages/admin_password_reset_page.dart | captured | admin__AdminForgotPasswordPage.png |
| admin | AdminLoginPage | lib/admin/pages/admin_login_page.dart | captured | admin__AdminLoginPage.png |
| admin | AdminManagementPage | lib/admin/pages/admin_management_page.dart | captured | admin__AdminManagementPage.png |
| admin | AdminShell | lib/admin/pages/admin_shell.dart | captured | admin__AdminShell.png |
| admin | AdminShellPlaceholder | lib/admin/pages/admin_login_page.dart | captured | admin__AdminShellPlaceholder.png |
| admin | BusinessReviewPage | lib/admin/pages/business_review_page.dart | captured | admin__BusinessReviewPage.png |
| admin | DepositsManagementPage | lib/admin/pages/deposits_management_page.dart | captured | admin__DepositsManagementPage.png |
| admin | EscrowManagementPage | lib/admin/pages/escrow_management_page.dart | captured | admin__EscrowManagementPage.png |
| admin | FeeManagementPage | lib/admin/pages/fee_management_page.dart | captured | admin__FeeManagementPage.png |
| admin | FeeManagementPage | lib/pages/superadmin/fee_management_page.dart | captured | superadmin__FeeManagementPage.png |
| admin | MerchantKybManagementPage | lib/admin/pages/merchant_kyb_management_page.dart | captured | admin__MerchantKybManagementPage.png |
| admin | NotificationsManagementPage | lib/admin/pages/notifications_management_page.dart | captured | admin__NotificationsManagementPage.png |
| admin | PaymentsMonitorPage | lib/admin/pages/monitoring_pages.dart | captured | admin__PaymentsMonitorPage.png |
| admin | ProjectsReviewPage | lib/admin/pages/monitoring_pages.dart | captured | admin__ProjectsReviewPage.png |
| admin | ResetPasswordPage | lib/admin/pages/admin_password_reset_page.dart | captured | admin__ResetPasswordPage.png |
| admin | SettingsManagementPage | lib/admin/pages/settings_management_page.dart | captured | admin__SettingsManagementPage.png |
| admin | SuperadminDashboardPage | lib/pages/superadmin/superadmin_dashboard_page.dart | captured | superadmin__SuperadminDashboardPage.png |
| admin | SuperadminWalletPage | lib/pages/superadmin/superadmin_wallet_page.dart | captured | superadmin__SuperadminWalletPage.png |
| admin | SuperadminsManagementPage | lib/admin/pages/superadmins_management_page.dart | captured | admin__SuperadminsManagementPage.png |
| admin | SupportInboxPage | lib/admin/pages/support_inbox_page.dart | captured | admin__SupportInboxPage.png |
| admin | TokenizationReviewPage | lib/admin/pages/monitoring_pages.dart | captured | admin__TokenizationReviewPage.png |
| admin | TransactionsManagementPage | lib/admin/pages/transactions_management_page.dart | captured | admin__TransactionsManagementPage.png |
| admin | TravelReviewPage | lib/admin/pages/travel_review_page.dart | captured | admin__TravelReviewPage.png |
| admin | UserManagementPage | lib/admin/pages/user_management_page.dart | captured | admin__UserManagementPage.png |
| admin | WithdrawalsManagementPage | lib/admin/pages/withdrawals_management_page.dart | captured | admin__WithdrawalsManagementPage.png |
| auth | BiometricSecurityPageWidget | lib/pages/biometric_security_page/biometric_security_page_widget.dart | captured | biometric_security_page__BiometricSecurityPageWidget.png |
| auth | BiometricUnlockPageWidget | lib/pages/biometric_unlock_page/biometric_unlock_page_widget.dart | captured | biometric_unlock_page__BiometricUnlockPageWidget.png |
| auth | ChangePinPageWidget | lib/pages/change_pin_page/change_pin_page_widget.dart | captured | change_pin_page__ChangePinPageWidget.png |
| auth | ForgotPasswordPageWidget | lib/pages/forgot_password_page/forgot_password_page_widget.dart | captured | forgot_password_page__ForgotPasswordPageWidget.png |
| auth | ForgotPinPageWidget | lib/pages/forgot_pin_page/forgot_pin_page_widget.dart | captured | forgot_pin_page__ForgotPinPageWidget.png |
| auth | KycpageWidget | lib/pages/kyc/kycpage_widget.dart | captured | kyc__KycpageWidget.png |
| auth | LoginpageWidget | lib/pages/loginpage/loginpage_widget.dart | captured but blank (needs live login session) | loginpage__LoginpageWidget.png |
| auth | OnboardingWidget | lib/pages/onboarding/onboarding_widget.dart | captured | onboarding__OnboardingWidget.png |
| auth | OtppageWidget | lib/pages/otppage/otppage_widget.dart | captured | otppage__OtppageWidget.png |
| auth | PinSetupPageWidget | lib/pages/pin_setup_page/pin_setup_page_widget.dart | captured | pin_setup_page__PinSetupPageWidget.png |
| auth | RegisterpageWidget | lib/pages/registerpage/registerpage_widget.dart | captured | registerpage__RegisterpageWidget.png |
| auth | ResetPasswordPageWidget | lib/pages/reset_password_page/reset_password_page_widget.dart | captured | reset_password_page__ResetPasswordPageWidget.png |
| auth | SessionsPage | lib/pages/security/sessions_page.dart | captured | security__SessionsPage.png |
| auth | SplashPage | lib/pages/splash_page.dart | captured | splash_page.dart__SplashPage.png |
| auth | VerifyEmailPageWidget | lib/pages/verify_email_page/verify_email_page_widget.dart | captured | verify_email_page__VerifyEmailPageWidget.png |
| business | AnalyticsPage | lib/pages/business/ops/money_pages.dart | captured | business__AnalyticsPage.png |
| business | ApiDocsPage | lib/pages/business/ops/developer_pages.dart | captured | business__ApiDocsPage.png |
| business | ApiKeysPage | lib/pages/business/ops/developer_pages.dart | captured | business__ApiKeysPage.png |
| business | ApiPermissionsPage | lib/pages/business/ops/developer_pages.dart | captured | business__ApiPermissionsPage.png |
| business | ApiUsagePage | lib/pages/business/ops/developer_pages.dart | captured | business__ApiUsagePage.png |
| business | BizFab | lib/pages/business/ops/ops_ui.dart | captured | business__BizFab.png |
| business | BizScaffold | lib/pages/business/ops/ops_ui.dart | captured | business__BizScaffold.png |
| business | BizTile | lib/pages/business/ops/ops_ui.dart | captured | business__BizTile.png |
| business | BusinessEscrowDetailPage | lib/pages/business/ops/escrow_pages.dart | captured | business__BusinessEscrowDetailPage.png |
| business | BusinessEscrowsPage | lib/pages/business/ops/escrow_pages.dart | captured | business__BusinessEscrowsPage.png |
| business | BusinessOnboardingPage | lib/pages/business/business_onboarding_page.dart | captured | business__BusinessOnboardingPage.png |
| business | BusinessProfilePage | lib/pages/business/ops/team_pages.dart | captured | business__BusinessProfilePage.png |
| business | BusinessProjectDetailPage | lib/pages/business/ops/project_pages.dart | captured | business__BusinessProjectDetailPage.png |
| business | BusinessProjectsPage | lib/pages/business/ops/project_pages.dart | captured | business__BusinessProjectsPage.png |
| business | BusinessStatusPage | lib/pages/business/business_status_page.dart | captured | business__BusinessStatusPage.png |
| business | BusinessTransactionsPage | lib/pages/business/ops/money_pages.dart | captured | business__BusinessTransactionsPage.png |
| business | BusinessWalletPage | lib/pages/business/ops/money_pages.dart | captured | business__BusinessWalletPage.png |
| business | CreateBusinessEscrowPage | lib/pages/business/ops/escrow_pages.dart | captured | business__CreateBusinessEscrowPage.png |
| business | CreateInvoicePage | lib/pages/business/ops/commerce_pages.dart | captured | business__CreateInvoicePage.png |
| business | CreatePaymentLinkPage | lib/pages/business/ops/commerce_pages.dart | captured | business__CreatePaymentLinkPage.png |
| business | CustomerDetailPage | lib/pages/business/ops/commerce_pages.dart | captured | business__CustomerDetailPage.png |
| business | CustomerFormPage | lib/pages/business/ops/commerce_pages.dart | captured | business__CustomerFormPage.png |
| business | CustomersPage | lib/pages/business/ops/commerce_pages.dart | captured | business__CustomersPage.png |
| business | DeveloperHomePage | lib/pages/business/ops/developer_pages.dart | captured | business__DeveloperHomePage.png |
| business | InvoiceDetailPage | lib/pages/business/ops/commerce_pages.dart | captured | business__InvoiceDetailPage.png |
| business | InvoicesPage | lib/pages/business/ops/commerce_pages.dart | captured | business__InvoicesPage.png |
| business | MilestoneEditorPage | lib/pages/business/ops/project_pages.dart | captured | business__MilestoneEditorPage.png |
| business | PayBusinessPage | lib/pages/business/ops/pay_business_page.dart | captured | business__PayBusinessPage.png |
| business | PaymentLinkDetailPage | lib/pages/business/ops/commerce_pages.dart | captured | business__PaymentLinkDetailPage.png |
| business | PaymentLinksPage | lib/pages/business/ops/commerce_pages.dart | captured | business__PaymentLinksPage.png |
| business | PayoutsPage | lib/pages/business/ops/money_pages.dart | captured | business__PayoutsPage.png |
| business | ProjectEditorPage | lib/pages/business/ops/project_pages.dart | captured | business__ProjectEditorPage.png |
| business | RequestLogsPage | lib/pages/business/ops/developer_pages.dart | captured | business__RequestLogsPage.png |
| business | RequestPayoutPage | lib/pages/business/ops/money_pages.dart | captured | business__RequestPayoutPage.png |
| business | TeamPage | lib/pages/business/ops/team_pages.dart | captured | business__TeamPage.png |
| business | TokenizationCard | lib/pages/business/ops/project_pages.dart | captured | business__TokenizationCard.png |
| business | TransactionDetailPage | lib/pages/business/ops/money_pages.dart | captured | business__TransactionDetailPage.png |
| business | WebhookDetailPage | lib/pages/business/ops/developer_pages.dart | captured | business__WebhookDetailPage.png |
| business | WebhooksPage | lib/pages/business/ops/developer_pages.dart | captured | business__WebhooksPage.png |
| invest_projects | GrowthTrackingPageWidget | lib/pages/growth_tracking_page/growth_tracking_page_widget.dart | captured | growth_tracking_page__GrowthTrackingPageWidget.png |
| invest_projects | InvestmentMarketplaceWidget | lib/pages/investment_marketplace/investment_marketplace_widget.dart | captured | investment_marketplace__InvestmentMarketplaceWidget.png |
| invest_projects | MarketplaceBody | lib/pages/investments/investment_pages.dart | captured | investments__MarketplaceBody.png |
| invest_projects | PortfolioPage | lib/pages/investments/investment_pages.dart | captured | investments__PortfolioPage.png |
| invest_projects | ProjectDetailPage | lib/pages/investments/investment_pages.dart | captured | investments__ProjectDetailPage.png |
| invest_projects | TokensTab | lib/pages/investments/investment_pages.dart | captured | investments__TokensTab.png |
| merchant | EscrowHubWidget | lib/pages/escrow_hub/escrow_hub_widget.dart | captured | escrow_hub__EscrowHubWidget.png |
| merchant | MerchantDashboardWidget | lib/pages/merchant_dashboard/merchant_dashboard_widget.dart | captured | merchant_dashboard__MerchantDashboardWidget.png |
| merchant | MerchantPaymentWidget | lib/pages/merchant_payment/merchant_payment_widget.dart | captured | merchant_payment__MerchantPaymentWidget.png |
| merchant | MerchantSalesWidget | lib/pages/merchant_sales/merchant_sales_widget.dart | captured | merchant_sales__MerchantSalesWidget.png |
| mkulima_ai | AgentMandatesPage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__AgentMandatesPage.png |
| mkulima_ai | AgentPaymentsHomePage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__AgentPaymentsHomePage.png |
| mkulima_ai | AgentRequestsPage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__AgentRequestsPage.png |
| mkulima_ai | AssistantAuditPage | lib/pages/assistant/assistant_pages.dart | captured | assistant__AssistantAuditPage.png |
| mkulima_ai | AssistantChatPage | lib/pages/assistant/assistant_pages.dart | captured | assistant__AssistantChatPage.png |
| mkulima_ai | AssistantConversationsPage | lib/pages/assistant/assistant_pages.dart | captured | assistant__AssistantConversationsPage.png |
| mkulima_ai | AssistantSettingsPage | lib/pages/assistant/assistant_pages.dart | captured | assistant__AssistantSettingsPage.png |
| mkulima_ai | BusinessIntentPage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__BusinessIntentPage.png |
| mkulima_ai | BusinessIntentsPage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__BusinessIntentsPage.png |
| mkulima_ai | MkulimaActivityPage | lib/pages/mkulima/mkulima_pages.dart | captured | mkulima__MkulimaActivityPage.png |
| mkulima_ai | MkulimaHubPage | lib/pages/mkulima/mkulima_pages.dart | captured | mkulima__MkulimaHubPage.png |
| mkulima_ai | MkulimaServicesPage | lib/pages/mkulima/mkulima_pages.dart | captured | mkulima__MkulimaServicesPage.png |
| mkulima_ai | PayIntentPage | lib/pages/agent_payments/agent_payments_pages.dart | captured | agent_payments__PayIntentPage.png |
| mkulima_ai | X402PaymentsPage | lib/pages/x402/x402_pages.dart | captured | x402__X402PaymentsPage.png |
| mkulima_ai | X402ResourcePage | lib/pages/x402/x402_pages.dart | captured | x402__X402ResourcePage.png |
| mkulima_ai | X402ResourcesPage | lib/pages/x402/x402_pages.dart | captured | x402__X402ResourcesPage.png |
| settings_support | DeleteAccountPageWidget | lib/pages/settings/delete_account_page.dart | captured | settings__DeleteAccountPageWidget.png |
| settings_support | EmailSupportPageWidget | lib/pages/support/email_support_page_widget.dart | captured | support__EmailSupportPageWidget.png |
| settings_support | FaqPageWidget | lib/pages/support/faq_page_widget.dart | captured | support__FaqPageWidget.png |
| settings_support | LanguageSettingsPageWidget | lib/pages/settings/language_settings_page.dart | captured | settings__LanguageSettingsPageWidget.png |
| settings_support | LegalDocumentPageWidget | lib/pages/settings/legal_document_page.dart | captured | settings__LegalDocumentPageWidget.png |
| settings_support | LiveChatPageWidget | lib/pages/support/live_chat_page_widget.dart | captured | support__LiveChatPageWidget.png |
| settings_support | NotificationSettingsPageWidget | lib/pages/settings/notification_settings_page.dart | captured | settings__NotificationSettingsPageWidget.png |
| settings_support | ProfileSettingsWidget | lib/pages/profile_settings/profile_settings_widget.dart | captured | profile_settings__ProfileSettingsWidget.png |
| settings_support | SupportHelpCenterPageWidget | lib/pages/settings/support_help_center_page.dart | captured | settings__SupportHelpCenterPageWidget.png |
| travel | HotelBookingPage | lib/pages/travel/hotel_pages.dart | captured | travel__HotelBookingPage.png |
| travel | HotelBookingView | lib/pages/travel/hotel_pages.dart | captured | travel__HotelBookingView.png |
| travel | HotelCheckoutPage | lib/pages/travel/hotel_pages.dart | captured | travel__HotelCheckoutPage.png |
| travel | HotelResultsPage | lib/pages/travel/hotel_pages.dart | captured | travel__HotelResultsPage.png |
| travel | HotelSearchForm | lib/pages/travel/hotel_pages.dart | captured | travel__HotelSearchForm.png |
| travel | TravelBookingPage | lib/pages/travel/travel_pages.dart | captured | travel__TravelBookingPage.png |
| travel | TravelBookingsPage | lib/pages/travel/travel_pages.dart | captured | travel__TravelBookingsPage.png |
| travel | TravelHomePage | lib/pages/travel/travel_pages.dart | captured | travel__TravelHomePage.png |
| travel | TravelOfferPage | lib/pages/travel/travel_pages.dart | captured | travel__TravelOfferPage.png |
| travel | TravelResultsPage | lib/pages/travel/travel_pages.dart | captured | travel__TravelResultsPage.png |
| wallet_payments | AllRequestsWidget | lib/pages/send_receive/all_requests_widget.dart | captured | send_receive__AllRequestsWidget.png |
| wallet_payments | AllTransactionsWidget | lib/pages/all_transactions/all_transactions_widget.dart | captured | all_transactions__AllTransactionsWidget.png |
| wallet_payments | CryptoCheckoutPage | lib/pages/depositpage/crypto_checkout_page.dart | captured | depositpage__CryptoCheckoutPage.png |
| wallet_payments | DashboardWidget | lib/pages/dashboard/dashboard_widget.dart | captured | dashboard__DashboardWidget.png |
| wallet_payments | DepositpageWidget | lib/pages/depositpage/depositpage_widget.dart | captured | depositpage__DepositpageWidget.png |
| wallet_payments | IncomingRequestsWidget | lib/pages/payment_requests/incoming_requests_widget.dart | captured | payment_requests__IncomingRequestsWidget.png |
| wallet_payments | LegacyMerchantQrRedirectPage | lib/pages/public_pay_page.dart | captured | public_pay_page.dart__LegacyMerchantQrRedirectPage.png |
| wallet_payments | MoneyRequestApprovalPage | lib/pages/payment_requests/money_request_approval_page.dart | captured | payment_requests__MoneyRequestApprovalPage.png |
| wallet_payments | PaymentSuccessPage | lib/pages/payment_success_page.dart | captured | payment_success_page.dart__PaymentSuccessPage.png |
| wallet_payments | PublicPayPage | lib/pages/public_pay_page.dart | captured | public_pay_page.dart__PublicPayPage.png |
| wallet_payments | QRScannerWidget | lib/pages/q_r_scanner/q_r_scanner_widget.dart | captured | q_r_scanner__QRScannerWidget.png |
| wallet_payments | ReceiptDetailsPage | lib/pages/receipts/receipt_pages.dart | captured | receipts__ReceiptDetailsPage.png |
| wallet_payments | ReceiptHistoryPage | lib/pages/receipts/receipt_pages.dart | captured | receipts__ReceiptHistoryPage.png |
| wallet_payments | RequestMoneyWidget | lib/pages/payment_requests/request_money_widget.dart | captured | payment_requests__RequestMoneyWidget.png |
| wallet_payments | SendReceiveWidget | lib/pages/send_receive/send_receive_widget.dart | captured | send_receive__SendReceiveWidget.png |
| wallet_payments | UserNotificationsPageWidget | lib/pages/notifications/user_notifications_page_widget.dart | captured | notifications__UserNotificationsPageWidget.png |
| wallet_payments | WalletAddressPage | lib/pages/chain_wallet/wallet_address_page.dart | captured | chain_wallet__WalletAddressPage.png |
| wallet_payments | WithdrawpageWidget | lib/pages/withdrawpage/withdrawpage_widget.dart | captured | withdrawpage__WithdrawpageWidget.png |
| - | StatusChip | lib/pages/business/ops/ops_ui.dart | not captured: positional ctor (helper component, not a screen) | - |
| - | KeyValue | lib/pages/business/ops/ops_ui.dart | not captured: positional ctor (helper component, not a screen) | - |
| - | ProjectCard | lib/pages/investments/investment_pages.dart | not captured: positional ctor (helper component, not a screen) | - |
| - | MilestoneList | lib/pages/investments/investment_pages.dart | not captured: positional ctor (helper component, not a screen) | - |

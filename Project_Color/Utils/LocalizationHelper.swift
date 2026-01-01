//
//  LocalizationHelper.swift
//  Project_Color
//
//  多语言支持辅助工具
//

import Foundation

// MARK: - String Extension for Localization

extension String {
    /// 本地化字符串（简化版）
    /// 使用方式：
    /// Text("tab.scanner".localized)
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// 本地化字符串（带注释）
    /// 使用方式：
    /// Text("tab.scanner".localized(comment: "扫描标签"))
    func localized(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
    
    /// 本地化字符串（带参数）
    /// 使用方式：
    /// "greeting.user".localized(with: userName)
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Localization Manager

/// 多语言管理器
class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {}
    
    /// 当前语言代码（如 "en", "zh-Hans"）
    var currentLanguageCode: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 当前是否为中文
    var isChineseLanguage: Bool {
        return currentLanguageCode.hasPrefix("zh")
    }
    
    /// 当前是否为英文
    var isEnglishLanguage: Bool {
        return currentLanguageCode == "en"
    }
    
    /// 获取本地化字符串
    func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, comment: comment)
    }
}

// MARK: - Localization Keys (可选：类型安全的 Key 定义)

/// 本地化 Key 定义（类型安全，避免拼写错误）
/// 使用方式：Text(L10n.Tab.scanner)
enum L10n {
    // MARK: - Tab Bar
    enum Tab {
        static let scanner = "tab.scanner"
        static let album = "tab.album"
        static let emerge = "tab.emerge"
        static let mine = "tab.mine"
    }
    
    // MARK: - Common
    enum Common {
        static let confirm = "common.confirm"
        static let cancel = "common.cancel"
        static let done = "common.done"
        static let delete = "common.delete"
        static let save = "common.save"
        static let loading = "common.loading"
        static let error = "common.error"
        static let success = "common.success"
        static let close = "common.close"
        static let retry = "common.retry"
        static let upgrade = "common.upgrade"
        static let goToSettings = "common.go_to_settings"
    }
    
    // MARK: - Toast Messages
    enum Toast {
        static let featureInDevelopment = "toast.feature_in_development"
    }
    
    // MARK: - Kit
    enum Kit {
        static let viewDetails = "kit.view_details"
        static let unlockMoreModes = "kit.unlock_more_modes"
    }
    
    // MARK: - Mine/Kit View
    enum Mine {
        static let title = "mine.title"
        static let unlockAI = "mine.unlock_ai"
        static let cloudAlbum = "mine.cloud_album"
        static let photoDarkroom = "mine.photo_darkroom"
        static let developmentMode = "mine.development_mode"
        static let scanResultStyle = "mine.scan_result_style"
        static let colorLab = "mine.color_lab"
        static let iterationLog = "mine.iteration_log"
        static let privacyPolicy = "mine.privacy_policy"
        static let feedback = "mine.feedback"
        static let encourage = "mine.encourage"
        static let encourageSubtitle = "mine.encourage_subtitle"
        static let share = "mine.share"
        static let aboutFeelm = "mine.about_feelm"
    }
    
    // MARK: - Unlock AI Sheet
    enum UnlockAI {
        static let title = "unlock_ai.title"
        static let restore = "unlock_ai.restore"
        static let comparisonTitle = "unlock_ai.comparison_title"
        static let planBasic = "unlock_ai.plan_basic"
        static let planPro = "unlock_ai.plan_pro"
        static let featureICloud = "unlock_ai.feature_icloud"
        static let featureComposition = "unlock_ai.feature_composition"
        static let featureColorLookup = "unlock_ai.feature_color_lookup"
        static let featureRefresh = "unlock_ai.feature_refresh"
        static let featureDisplayMode = "unlock_ai.feature_display_mode"
        static let featureDisplayShape = "unlock_ai.feature_display_shape"
        static let featureShare = "unlock_ai.feature_share"
        static let valueBasicRefresh = "unlock_ai.value_basic_refresh"
        static let valueProRefresh = "unlock_ai.value_pro_refresh"
        static let valueBasicMode = "unlock_ai.value_basic_mode"
        static let valueProMode = "unlock_ai.value_pro_mode"
        static let pricingMonthly = "unlock_ai.pricing_monthly"
        static let pricingYearly = "unlock_ai.pricing_yearly"
        static let pricingLifetime = "unlock_ai.pricing_lifetime"
        static let priceEarlyBird = "unlock_ai.price_early_bird"
        static let priceMonthlyValue = "unlock_ai.price_monthly_value"
        static let priceYearlyValue = "unlock_ai.price_yearly_value"
        static let priceYearlyOriginal = "unlock_ai.price_yearly_original"
        static let priceLifetimeValue = "unlock_ai.price_lifetime_value"
        static let priceLifetimeOriginal = "unlock_ai.price_lifetime_original"
        static let upgradeNow = "unlock_ai.upgrade_now"
        static let privacyPolicy = "unlock_ai.privacy_policy"
        static let termsOfUse = "unlock_ai.terms_of_use"
        static let purchaseFailed = "unlock_ai.purchase_failed"
        static let restoreSuccess = "unlock_ai.restore_success"
        static let titleUpgrade = "unlock_ai.title_upgrade"
        static let titleProMember = "unlock_ai.title_pro_member"
        static let titleLifetimeMember = "unlock_ai.title_lifetime_member"
        static let processing = "unlock_ai.processing"
        static let restoreSuccessMessage = "unlock_ai.restore_success_message"
        static let ok = "unlock_ai.ok"
    }
    
    // MARK: - About View
    enum About {
        static let navigationTitle = "about.navigation_title"
        static let legalInfo = "about.legal_info"
        static let iterationLog = "about.iteration_log"
        static let termsOfUse = "about.terms_of_use"
        static let privacyPolicy = "about.privacy_policy"
    }
    
    // MARK: - Photo Darkroom
    enum Darkroom {
        static let title = "darkroom.title"
        static let usePhotoTime = "darkroom.use_photo_time"
        static let favoriteOnly = "darkroom.favorite_only"
        static let scanResultStyle = "darkroom.scan_result_style"
    }
    
    // MARK: - Development Mode
    enum DevelopmentMode {
        static let tone = "development_mode.tone"
        static let shadow = "development_mode.shadow"
        static let comprehensive = "development_mode.comprehensive"
    }
    
    // MARK: - Development Shape
    enum DevelopmentShape {
        static let title = "development_shape.title"
        static let circle = "development_shape.circle"
        static let flower = "development_shape.flower"
        static let gardenFlower = "development_shape.garden_flower"
    }
    
    // MARK: - Scan Result Style
    enum ScanResultStyle {
        static let perspectiveFirst = "scan_result_style.perspective_first"
        static let compositionFirst = "scan_result_style.composition_first"
    }
    
    // MARK: - Home View
    enum Home {
        static let title = "home.title"
        static let selectPhotos = "home.select_photos"
        static let startAnalysis = "home.start_analysis"
        static let analysisHistory = "home.analysis_history"
        static let settings = "home.settings"
        static let addFeeling = "home.add_feeling"
        static let scanPrepareTitle = "home.scan_prepare_title"
        static let scanPrepareMessage = "home.scan_prepare_message"
        static let processing = "home.processing"
        static let scanPreparing = "home.scan_preparing"
        static let confirmSelection = "home.confirm_selection"
        static let feelingPlaceholder = "home.feeling_placeholder"
        static let upgradeMessage = "home.upgrade_message"
        static let permissionRequired = "home.permission_required"
        static let permissionMessage = "home.permission_message"
        static let limitReachedTitle = "home.limit_reached_title"
        static let later = "home.later"
        static let characterCount = "home.character_count"
    }
    
    // MARK: - Favorite
    enum Favorite {
        static let title = "favorite.title"
        static let photoDate = "favorite.photo_date"
        static let cancel = "favorite.cancel"
        static let confirm = "favorite.confirm"
        static let remove = "favorite.remove"
        static let add = "favorite.add"
    }
    
    // MARK: - Album
    enum Album {
        static let title = "album.title"
        static let emptyTitle = "album.empty_title"
        static let emptyMessage = "album.empty_message"
        static let photosCount = "album.photos_count"
        static let photosCountSingular = "album.photos_count_singular"
        static let editInfo = "album.edit_info"
        static let delete = "album.delete"
        static let deleteConfirmTitle = "album.delete_confirm_title"
        static let deleteConfirmMessage = "album.delete_confirm_message"
        static let editTitle = "album.edit_title"
        static let name = "album.name"
        static let namePlaceholder = "album.name_placeholder"
        
        /// 根据照片数量返回正确的本地化字符串（单数/复数）
        static func photosCountText(count: Int) -> String {
            if count == 1 {
                return photosCountSingular.localized(with: count)
            } else {
                return photosCount.localized(with: count)
            }
        }
    }
    
    // MARK: - Analysis Library
    enum AnalysisLibrary {
        static let title = "analysis_library.title"
        static let favorites = "analysis_library.favorites"
        static let materials = "analysis_library.materials"
        static let emptyFavorites = "analysis_library.empty_favorites"
        static let emptyMaterials = "analysis_library.empty_materials"
        static let deleteConfirmTitle = "analysis_library.delete_confirm_title"
        static let deleteConfirmMessage = "analysis_library.delete_confirm_message"
        static let delete = "analysis_library.delete"
        static let cancel = "analysis_library.cancel"
        static let loading = "analysis_library.loading"
        static let editDate = "analysis_library.edit_date"
    }
    
    // MARK: - Emerge View
    enum Emerge {
        static let loading = "emerge.loading"
        static let insufficientPhotos = "emerge.insufficient_photos"
        static let insufficientFavorites = "emerge.insufficient_favorites"
        static let currentScanned = "emerge.current_scanned"
        static let currentFavorited = "emerge.current_favorited"
        static let errorTitle = "emerge.error_title"
        static let emptyMessage = "emerge.empty_message"
    }
    
    // MARK: - Photo Card
    enum PhotoCard {
        static let loadFailed = "photo_card.load_failed"
    }
    
    // MARK: - Photo Detail
    enum PhotoDetail {
        static let noTags = "photo_detail.no_tags"
        static let loadFailed = "photo_detail.load_failed"
    }
    
    // MARK: - Album Photos
    enum AlbumPhotos {
        static let noPhotos = "album_photos.no_photos"
        static let deletedMessage = "album_photos.deleted_message"
    }
    
    // MARK: - Native Album Photos
    enum NativeAlbumPhotos {
        static let emptyAlbum = "native_album_photos.empty_album"
        static let loadFailed = "native_album_photos.load_failed"
    }
    
    // MARK: - Brightness CDF
    enum BrightnessCDF {
        static let noData = "brightness_cdf.no_data"
        static let photoCount = "brightness_cdf.photo_count"
    }
    
    // MARK: - Saturation Brightness Scatter
    enum SaturationBrightnessScatter {
        static let noData = "saturation_brightness_scatter.no_data"
        static let description = "saturation_brightness_scatter.description"
    }
    
    // MARK: - Color Cast Scatter
    enum ColorCastScatter {
        static let title = "color_cast_scatter.title"
        static let description = "color_cast_scatter.description"
        static let highlightTitle = "color_cast_scatter.highlight_title"
        static let highlightDescription = "color_cast_scatter.highlight_description"
        static let shadowTitle = "color_cast_scatter.shadow_title"
        static let shadowDescription = "color_cast_scatter.shadow_description"
    }
    
    // MARK: - Temperature Distribution
    enum TemperatureDistribution {
        static let cool = "temperature_distribution.cool"
        static let warm = "temperature_distribution.warm"
    }
    
    // MARK: - Warm Cool Histogram
    enum WarmCoolHistogram {
        static let title = "warm_cool_histogram.title"
        static let cool = "warm_cool_histogram.cool"
        static let neutral = "warm_cool_histogram.neutral"
        static let warm = "warm_cool_histogram.warm"
    }
    
    // MARK: - Analysis Result
    enum AnalysisResult {
        static let title = "analysis_result.title"
        static let perspective = "analysis_result.perspective"
        static let aiEvaluationFailed = "analysis_result.ai_evaluation_failed"
        static let analysisComplete = "analysis_result.analysis_complete"
        static let photosUnit = "analysis_result.photos_unit"
        static let clusterQuality = "analysis_result.cluster_quality"
        static let optimalClusters = "analysis_result.optimal_clusters"
        static let silhouetteScore = "analysis_result.silhouette_score"
        static let clusterCountChange = "analysis_result.cluster_count_change"
        static let possibleReasons = "analysis_result.possible_reasons"
        static let adjustmentHint = "analysis_result.adjustment_hint"
        static let clustersCount = "analysis_result.clusters_count"
        static let photosCountInCluster = "analysis_result.photos_count_in_cluster"
        static let composition = "analysis_result.composition"
        static let share = "analysis_result.share"
        static let favorite = "analysis_result.favorite"
        static let aiEvaluation = "analysis_result.ai_evaluation"
        static let distribution = "analysis_result.distribution"
        static let pickerTitle = "analysis_result.picker_title"
        static let aiLoading = "analysis_result.ai_loading"
        static let clusterInfo = "analysis_result.initial_clusters_text"
        static let failedCount = "analysis_result.processing_failed"
        static let aiLoadingRefresh = "analysis_result.ai_loading_refresh"
        static let aiLoadingSubtitle = "analysis_result.ai_loading_subtitle"
        static let aiError = "analysis_result.ai_error"
        static let retry = "analysis_result.retry"
        static let networkError = "analysis_result.network_error"
        static let noPerspective = "analysis_result.no_perspective"
        static let colorEvaluations = "analysis_result.color_evaluations"
        static let colorSystemsCount = "analysis_result.color_systems_count"
        static let categoryDetail = "analysis_result.category_detail"
        static let saturation = "analysis_result.saturation"
        static let brightness = "analysis_result.brightness"
        static let cumulativePercentage = "analysis_result.cumulative_percentage"
        static let brightnessCdfTitle = "analysis_result.brightness_cdf_title"
        static let brightnessCdfDescription = "analysis_result.brightness_cdf_description"
        static let brightnessCalculating = "analysis_result.brightness_calculating"
    }
    
    // MARK: - Lab View
    enum Lab {
        static let title = "lab.title"
        static let searchColor = "lab.search_color"
        static let searchColorSubtitle = "lab.search_color_subtitle"
        static let calculateColor = "lab.calculate_color"
        static let calculateColorSubtitle = "lab.calculate_color_subtitle"
        static let lookupColor = "lab.lookup_color"
    }
    
    // MARK: - 3D Color Space
    enum ThreeDView {
        static let lchExplanation = "3d_view.lch_explanation"
    }
    
    // MARK: - iCloud Sync
    enum CloudSync {
        static let title = "cloud_sync.title"
        static let enable = "cloud_sync.enable"
        static let disable = "cloud_sync.disable"
        static let cancel = "cloud_sync.cancel"
        static let enableAndRestart = "cloud_sync.enable_and_restart"
        static let syncStatus = "cloud_sync.sync_status"
        static let statusEnabled = "cloud_sync.status_enabled"
        static let statusDisabled = "cloud_sync.status_disabled"
        static let promptTitle = "cloud_sync.prompt_title"
        static let promptMessage = "cloud_sync.prompt_message"
        static let promptMessageWithRestart = "cloud_sync.prompt_message_with_restart"
        static let restartTitle = "cloud_sync.restart_title"
        static let restartMessage = "cloud_sync.restart_message"
        static let restartConfirm = "cloud_sync.restart_confirm"
        static let dataStats = "cloud_sync.data_stats"
        static let statsSessions = "cloud_sync.stats_sessions"
        static let statsPhotos = "cloud_sync.stats_photos"
        static let statsSize = "cloud_sync.stats_size"
        static let aboutTitle = "cloud_sync.about_title"
        static let aboutMultiDevice = "cloud_sync.about_multi_device"
        static let aboutStorage = "cloud_sync.about_storage"
        static let aboutNetwork = "cloud_sync.about_network"
        static let aboutPhotoReference = "cloud_sync.about_photo_reference"
    }
    
    // MARK: - Analysis Result Details
    enum AnalysisResultDetail {
        static let processingFailed = "analysis_result.processing_failed"
        static let photosCountText = "analysis_result.photos_count_text"
        static let initialClustersText = "analysis_result.initial_clusters_text"
        static let kValue = "analysis_result.k_value"
        static let processedCount = "analysis_result.processed_count"
    }
    
    // MARK: - Hue Ring Distribution
    enum HueRing {
        static let noData = "hue_ring.no_data"
    }
    
    // MARK: - Search Color
    enum SearchColor {
        static let matchedPhotos = "search_color.matched_photos"
        static let iosOnly = "search_color.ios_only"
    }
    
    // MARK: - Lookup Color
    enum LookupColor {
        static let hexPlaceholder = "lookup_color.hex_placeholder"
        static let iosOnly = "lookup_color.ios_only"
    }
    
    // MARK: - Limited Library
    enum LimitedLibrary {
        static let maxSelectionToast = "limited_library.max_selection_toast"
        static let analyzeButton = "limited_library.analyze_button"
    }
    
    // MARK: - Analysis Limit
    enum AnalysisLimit {
        static let monthlyUsage = "analysis_limit.monthly_usage"
        static let view = "analysis_limit.view"
        static let upgradePro = "analysis_limit.upgrade_pro"
    }
    
    // MARK: - Membership
    enum Membership {
        static let free = "membership.free"
        static let monthly = "membership.monthly"
        static let yearly = "membership.yearly"
        static let lifetime = "membership.lifetime"
    }
    
    // MARK: - Photo Picker
    enum PhotoPicker {
        static let maxSelection = "photo_picker.max_selection"
    }
    
    // MARK: - Photo Stack
    enum PhotoStack {
        static let iosOnly = "photo_stack.ios_only"
    }
}

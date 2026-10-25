# 图标资源：523 个 SVG 由 scripts/sync-icons.py 从 semi-icons 同步，
# 全量打包约 2MB，不值得为省这点体积维护一份挑拣清单
file(GLOB SEMI_ICON_SVGS CONFIGURE_DEPENDS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" "icons/*.svg")

qt_add_qml_module(semi
    URI Semi
    VERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    SHARED
    QML_FILES
        Anchor.qml
        AnchorLink.qml
        AutoComplete.qml
        Avatar.qml
        AvatarGroup.qml
        BackTop.qml
        Badge.qml
        Banner.qml
        Breadcrumb.qml
        BreadcrumbItem.qml
        BreadcrumbMore.qml
        Button.qml
        ButtonGroup.qml
        Calendar.qml
        Card.qml
        CardGroup.qml
        CardMeta.qml
        CalendarDate.js
        CalendarEventBody.qml
        CalendarMonth.qml
        CalendarTimeGrid.qml
        Carousel.qml
        CarouselArrow.qml
        CarouselIndicator.qml
        Cascader.qml
        Checkbox.qml
        CheckboxGroup.qml
        ColorConvert.js
        CssGradient.js
        InputNumberCurrency.js
        ColorPicker.qml
        Collapse.qml
        Collapsible.qml
        CollapsePanel.qml
        Descriptions.qml
        DescriptionsItem.qml
        DateFormat.js
        DateMonthGrid.qml
        DatePicker.qml
        DatePanelColumn.qml
        DateQuickControl.qml
        DateScrollColumn.qml
        DateTimeColumns.qml
        DateYearMonthPanel.qml
        Divider.qml
        DragMove.qml
        Dropdown.qml
        Cropper.qml
        DropdownItem.qml
        DropdownTitle.qml
        DropdownDivider.qml
        Empty.qml
        Feedback.qml
        FloatButton.qml
        Form.qml
        FormArrayField.qml
        FormErrorMessage.qml
        FormInputGroup.qml
        InputGroup.qml
        FormItem.qml
        FormLabel.qml
        FormSection.qml
        FormSlot.qml
        Highlight.qml
        HotKeys.qml
        Icon.qml
        IconButton.qml
        ImagePreview.qml
        ImagePreviewInner.qml
        ImageView.qml
        Input.qml
        InputNumber.qml
        InputNumberStepper.qml
        List.qml
        ListItem.qml
        Modal.qml
        ModalConfirm.qml
        ModalEscStack.js
        ModalHost.qml
        Navigation.qml
        NavigationCollapseButton.qml
        NavigationEntry.qml
        NavigationFooter.qml
        NavigationHeader.qml
        NavigationItem.qml
        NavigationSub.qml
        NavigationSubEntries.qml
        Notification.qml
        NotificationItem.qml
        Numeral.qml
        OverflowList.qml
        Pagination.qml
        PaginationRestList.qml
        Paragraph.qml
        PinCode.qml
        Popconfirm.qml
        Popover.qml
        PopupBase.qml
        Progress.qml
        ProgressStroke.js
        Radio.qml
        RadioGroup.qml
        Rating.qml
        RatingGlyph.qml
        ScrollItem.qml
        ScrollList.qml
        Select.qml
        SemiPopupShadow.qml
        SemiScrollBar.qml
        SideSheet.qml
        Skeleton.qml
        SkeletonAvatar.qml
        SkeletonBlock.qml
        SkeletonButton.qml
        SkeletonImage.qml
        SkeletonParagraph.qml
        SkeletonTitle.qml
        Slider.qml
        Space.qml
        Spin.qml
        SplitButtonGroup.qml
        SplitTagGroup.qml
        Step.qml
        Steps.qml
        Switch.qml
        Table.qml
        TableColumn.qml
        TableEngine.js
        TableFilterPanel.qml
        TabItem.qml
        TabPane.qml
        Tabs.qml
        Tag.qml
        TagGroup.qml
        TagInput.qml
        TextArea.qml
        TextLabel.qml
        TimePicker.qml
        TimePickerPanel.qml
        Timeline.qml
        TimelineItem.qml
        Toast.qml
        ToastItem.qml
        Tooltip.qml
        Upload.qml
        UserGuide.qml
        TreeSelect.qml
        TreeSelectOption.qml
        Title.qml
        TypographyBase.qml
        Transfer.qml
        TransferRightItem.qml
        Tree.qml
        TreeRow.qml
        TreeEngine.js
    RESOURCES
        ${SEMI_ICON_SVGS}
    SOURCES
        Theme.h
        CropperRuntime.cpp
        Theme.cpp
        Enums.h
        Appearance.h
        Appearance.cpp
        FocusVisible.h
        FocusVisible.cpp
        SemiThemeValues.h
        SemiThemeValues.cpp
)

# 下游统一用 Semi::Semi 引入
set_target_properties(semi PROPERTIES EXPORT_NAME Semi)

target_link_libraries(semi PRIVATE Qt6::Quick)

install(TARGETS semi
    EXPORT SemiTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# 插件与 qmldir 落到 Qt 的 QML 导入目录下，纯 QML 工程可直接 import；
# 它们不参与 CMake 导出
install(TARGETS semiplugin
    LIBRARY DESTINATION ${QT6_INSTALL_QML}/Semi
    RUNTIME DESTINATION ${QT6_INSTALL_QML}/Semi
)

qt_query_qml_module(semi
    QMLDIR semi_qmldir
    TYPEINFO semi_typeinfo
)

install(FILES ${semi_qmldir} ${semi_typeinfo}
    DESTINATION ${QT6_INSTALL_QML}/Semi
)

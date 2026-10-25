find_package(Qt6 6.5 REQUIRED COMPONENTS QuickTest)

qt_add_executable(tst_semi tst_semi.cpp)

target_link_libraries(tst_semi PRIVATE
    Qt6::Quick
    Qt6::QuickTest
    semi
)

target_compile_definitions(tst_semi PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

# 图片用例的夹具：三张已知尺寸的 PNG 编进测试目标的资源里
# （qrc:/tests/img_wide.png 480×270、img_tall.png 270×480、img_small.png 60×40）
# crop_quads.png 200×100 是给 Cropper 用的四色块（红/绿/蓝/白各占一角，边界在中点），
# 裁切结果与圆形遮罩都要能「按坐标读出一个已知颜色」。
qt_add_resources(tst_semi "image_fixtures"
    PREFIX "/tests"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    FILES
        assets/img_wide.png
        assets/img_tall.png
        assets/img_small.png
        assets/square_200.svg
        assets/crop_quads.png
)

# 一个可执行文件 + -input 指定文件，每个 tst_*.qml 注册成一个独立用例
set(SEMI_TEST_FILES
    tst_theme.qml
    tst_appearance.qml
    tst_icon.qml
    tst_form.qml
    tst_misc.qml
    tst_display.qml
    tst_avatar.qml
    tst_controls.qml
    tst_nav.qml
    tst_popup.qml
    tst_modal.qml
    tst_sidesheet.qml
    tst_feedback.qml
    tst_banner.qml
    tst_input2.qml
    tst_input3.qml
    tst_date.qml
    tst_form2.qml
    tst_form3.qml
    tst_input4.qml
    tst_inputnumber.qml
    tst_radio.qml
    tst_rating.qml
    tst_pincode.qml
    tst_transfer.qml
    tst_treeselect.qml
    tst_upload.qml
    tst_p5.qml
    tst_overflowlist.qml
    tst_calendar.qml
    tst_extras.qml
    tst_userguide.qml
    tst_list.qml
    tst_navigation.qml
    tst_scrollbar.qml
    tst_scrolllist.qml
    tst_space.qml
    tst_table.qml
    tst_button.qml
    tst_switch.qml
    tst_loaderinject.qml
    tst_timepicker.qml
    tst_tag.qml
    tst_taginput.qml
    tst_toast.qml
    tst_notification.qml
    tst_progress.qml
    tst_spin.qml
    tst_skeleton.qml
    tst_tooltip.qml
    tst_popover.qml
    tst_timeline.qml
    tst_image.qml
    tst_highlight.qml
    tst_empty.qml
    tst_dropdown.qml
    tst_cropper.qml
    tst_descriptions.qml
    tst_divider.qml
    tst_card.qml
    tst_carousel.qml
    tst_badge.qml
    tst_tree.qml
    tst_steps.qml
    tst_tabs.qml
    tst_pagination.qml
    tst_breadcrumb.qml
    tst_backtop.qml
    tst_anchor.qml
)

foreach(test_file IN LISTS SEMI_TEST_FILES)
    get_filename_component(test_name "${test_file}" NAME_WE)
    add_test(NAME ${test_name}
        COMMAND tst_semi -input ${CMAKE_CURRENT_SOURCE_DIR}/${test_file}
    )
endforeach()

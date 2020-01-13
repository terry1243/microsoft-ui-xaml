// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

// DO NOT EDIT! This file was generated by CustomTasks.DependencyPropertyCodeGen
#include "pch.h"
#include "common.h"
#include "MenuBar.h"

namespace winrt::Microsoft::UI::Xaml::Controls
{
    CppWinRTActivatableClassWithDPFactory(MenuBar)
}

#include "MenuBar.g.cpp"

GlobalDependencyProperty MenuBarProperties::s_ItemsProperty{ nullptr };

MenuBarProperties::MenuBarProperties()
{
    EnsureProperties();
}

void MenuBarProperties::EnsureProperties()
{
    if (!s_ItemsProperty)
    {
        s_ItemsProperty =
            InitializeDependencyProperty(
                L"Items",
                winrt::name_of<winrt::IVector<winrt::MenuBarItem>>(),
                winrt::name_of<winrt::MenuBar>(),
                false /* isAttached */,
                ValueHelper<winrt::IVector<winrt::MenuBarItem>>::BoxedDefaultValue(),
                nullptr);
    }
}

void MenuBarProperties::ClearProperties()
{
    s_ItemsProperty = nullptr;
}

void MenuBarProperties::Items(winrt::IVector<winrt::MenuBarItem> const& value)
{
    static_cast<MenuBar*>(this)->SetValue(s_ItemsProperty, ValueHelper<winrt::IVector<winrt::MenuBarItem>>::BoxValueIfNecessary(value));
}

winrt::IVector<winrt::MenuBarItem> MenuBarProperties::Items()
{
    return ValueHelper<winrt::IVector<winrt::MenuBarItem>>::CastOrUnbox(static_cast<MenuBar*>(this)->GetValue(s_ItemsProperty));
}

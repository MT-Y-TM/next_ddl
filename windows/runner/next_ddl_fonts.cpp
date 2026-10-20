#include "next_ddl_fonts.h"

#include <windows.h>
#include <set>
#include <string>

namespace {
using flutter::EncodableList;
using flutter::EncodableValue;

int CALLBACK CollectFontFamily(const LOGFONTW* font, const TEXTMETRICW*,
                              DWORD, LPARAM data) {
  auto* families = reinterpret_cast<std::set<std::wstring>*>(data);
  if (font != nullptr && font->lfFaceName[0] != L'\0') {
    families->insert(font->lfFaceName);
  }
  return 1;
}

std::string ToUtf8(const std::wstring& value) {
  if (value.empty()) return {};
  const auto length = WideCharToMultiByte(CP_UTF8, 0, value.data(),
      static_cast<int>(value.size()), nullptr, 0, nullptr, nullptr);
  std::string result(length, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
      result.data(), length, nullptr, nullptr);
  return result;
}
}

NextDdlFonts::NextDdlFonts(flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "next_ddl/fonts",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() != "listFontFamilies") {
      result->NotImplemented();
      return;
    }
    std::set<std::wstring> families;
    LOGFONTW font{};
    font.lfCharSet = DEFAULT_CHARSET;
    HDC device = GetDC(nullptr);
    if (device != nullptr) {
      EnumFontFamiliesExW(device, &font, CollectFontFamily,
                          reinterpret_cast<LPARAM>(&families), 0);
      ReleaseDC(nullptr, device);
    }
    EncodableList values;
    for (const auto& family : families) {
      values.emplace_back(ToUtf8(family));
    }
    result->Success(EncodableValue(values));
  });
}

NextDdlFonts::~NextDdlFonts() {
  channel_->SetMethodCallHandler(nullptr);
}

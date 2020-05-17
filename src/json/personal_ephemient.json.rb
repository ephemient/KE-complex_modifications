#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/karabiner.rb'

APPLE_VENDOR_ID = 1452
def apple_device_if
  {
    type: 'device_if',
    identifiers: [{description: 'Apple', vendor_id: APPLE_VENDOR_ID}],
  }
end
def apple_device_unless
  {
    type: 'device_unless',
    identifiers: [{description: 'Apple', vendor_id: APPLE_VENDOR_ID}],
  }
end

MICROSOFT_VENDOR_ID = 1118
MICROSOFT_KEYBOARD_PRODUCTS = {1936 => 'Wedge Mobile Keyboard'}
MICROSOFT_MOUSE_PRODUCTS = {1954 => 'Sculpt Comfort Mouse'}
def microsoft_keyboard_device_if
  {
    type: 'device_if',
    identifiers: MICROSOFT_KEYBOARD_PRODUCTS.map { |id, name|
      {description: "Microsoft #{name}", vendor_id: MICROSOFT_VENDOR_ID, product_id: id}
    },
  }
end
def microsoft_mouse_device_if
  {
    type: 'device_if',
    identifiers: MICROSOFT_MOUSE_PRODUCTS.map { |id, name|
      {description: name, vendor_id: MICROSOFT_VENDOR_ID, product_id: id}
    },
  }
end

def command_option_swap_manipulators
  buttons = %w[command option]
  %w[left right].flat_map { |side|
    [buttons, buttons.reverse].map { |from, to|
      {
        type: 'basic',
        from: {
          key_code: "#{side}_#{from}",
          modifiers: {optional: %w[any]}
        },
        to: [{key_code: "#{side}_#{to}"}],
      }
    }
  }
end

def main
  puts JSON.pretty_generate(
    title: 'Personal rules (@ephemient)',
    rules: [
      {
        description: 'Application to Option on Microsoft keyboards',
        manipulators: [
          {
            type: 'basic',
            conditions: [
              microsoft_keyboard_device_if,
              Karabiner.frontmost_application_unless(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
            from: {key_code: 'application'},
            to: [{key_code: 'right_option'}],
          }
        ]
      },
      {
        description: 'Microsoft mouse button to Mission Control',
        manipulators: [
          {
            type: 'basic',
            parameters: {'basic.to_if_held_down_threshold_milliseconds' => 250},
            conditions: [
              microsoft_mouse_device_if,
              Karabiner.frontmost_application_unless(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
            from: {key_code: 'left_command'},
            to_if_alone: [{key_code: 'mission_control'}],
            to_if_held_down: [{key_code: 'mission_control'}],
          },
          {
            type: 'basic',
            conditions: [
              microsoft_mouse_device_if,
              Karabiner.frontmost_application_unless(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
            from: {
              key_code: 'tab',
              modifiers: {optional: %w[left_control]}
            },
            to: [{key_code: 'left_arrow'}],
          },
          {
            type: 'basic',
            conditions: [
              microsoft_mouse_device_if,
              Karabiner.frontmost_application_unless(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
            from: {
              key_code: 'delete_or_backspace',
              modifiers: {optional: %w[left_control]}
            },
            to: [{key_code: 'right_arrow'}],
          },
        ]
      },
      {
        description: 'Caps Lock to Left Control (or Escape)',
        manipulators: [
          {
            type: 'basic',
            conditions: [Karabiner.frontmost_application_if(%w[terminal vi])],
            from: {key_code: 'caps_lock'},
            to: [{key_code: 'left_control', lazy: true}],
            to_if_alone: [{key_code: 'escape'}],
          },
          {
            type: 'basic',
            from: {
              key_code: 'caps_lock',
              modifiers: {optional: %w[any]}
            },
            to: [{key_code: 'left_control'}],
          }
        ]
      },
      {
        description: 'Alt/GUI to Command/Option on non-Apple keyboards',
        manipulators: command_option_swap_manipulators.map { |manipulator|
          manipulator.merge({
            conditions: [
              apple_device_unless,
              Karabiner.frontmost_application_unless(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
          })
        },
      },
      {
        description: 'Command/Option to Alt/GUI to Command/Option in RDP',
        manipulators: command_option_swap_manipulators.map { |manipulator|
          manipulator.merge({
            conditions: [
              apple_device_if,
              Karabiner.frontmost_application_if(
                %w[virtual_machine vnc remote_desktop],
                bundle_identifiers: %w[^com\.blade\.shadow-macos$],
              )
            ],
          })
        },
      },
    ],
  )
end

main
